import 'dart:convert';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/device_info_service.dart';
import 'log_buffer.dart';
import 'parazitx_manifest.dart';

class LogUploadResult {
  LogUploadResult._({required this.id, required this.error});
  factory LogUploadResult.ok(String id) =>
      LogUploadResult._(id: id, error: null);
  factory LogUploadResult.err(String message) =>
      LogUploadResult._(id: null, error: message);

  final String? id;
  final String? error;
  bool get isOk => id != null;
}

class LogUploader {
  LogUploader._();

  static const _uploadTimeout = Duration(seconds: 20);
  static const _serversHeaderName = 'dropweb-parazitx-servers';
  static const _manifestHeaderName = 'dropweb-parazitx-manifest';
  static const _relaysHeaderName = 'dropweb-parazitx-relays';
  static const _relayBackendHeaderName = 'X-Dropweb-Backend';
  static const _defaultManifestUrl =
      'https://sub.dropweb.org/parazitx/manifest.json';
  static const _maxPayloadBytes = 100 * 1024;

  static DateTime? _lastUploadAt;
  static const _minInterval = Duration(minutes: 5);

  static Future<LogUploadResult> send() async {
    final now = DateTime.now();
    if (_lastUploadAt != null) {
      final elapsed = now.difference(_lastUploadAt!);
      if (elapsed < _minInterval) {
        final remaining = _minInterval - elapsed;
        return LogUploadResult.err(
          'Слишком часто. Подождите ${remaining.inSeconds}s',
        );
      }
    }

    final lines = LogBuffer.instance.getAll();
    if (lines.isEmpty) {
      return LogUploadResult.err('Нет логов для отправки');
    }

    final trimmed = _trimToPayloadLimit(lines);

    final deviceId = await _resolveDeviceId();
    final appVersion = await _resolveAppVersion();

    final payload = jsonEncode({
      'device_id': deviceId,
      'app_version': appVersion,
      'timestamp': now.toUtc().toIso8601String(),
      'logs': trimmed,
    });

    // Try servers from subscription header
    final servers = _resolveServers();
    for (final server in servers) {
      final result = await _tryUpload(
        'http://$server/v1/logs',
        payload,
        _uploadTimeout,
        now,
      );
      if (result != null) return result;
    }

    // Try relays as fallback. Header relays win; when absent, use the
    // manifest registry so log upload still works after operators remove
    // stale direct backend headers from Remnawave subscriptions.
    final relays = await _resolveRelayTargets(servers);
    if (relays.isNotEmpty) {
      final primaryServer = servers.isNotEmpty ? servers.first : null;
      for (final relay in relays) {
        final result = await _tryUploadViaRelay(
          relay.url,
          relay.requiresBackendHeader ? primaryServer : null,
          payload,
          _uploadTimeout,
          now,
        );
        if (result != null) return result;
      }
    }

    return LogUploadResult.err('Нет доступных серверов логирования');
  }

  static Future<LogUploadResult?> _tryUpload(
    String url,
    String payload,
    Duration timeout,
    DateTime now,
  ) async {
    try {
      final resp = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(timeout);
      if (resp.statusCode == 200) {
        _lastUploadAt = now;
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final id = (data['id'] as String?) ?? 'ok';
          return LogUploadResult.ok(id);
        } catch (_) {
          return LogUploadResult.ok('ok');
        }
      }
      if (resp.statusCode == 429) {
        return LogUploadResult.err('Сервер: слишком часто (429)');
      }
      if (resp.statusCode == 413) {
        return LogUploadResult.err('Сервер: слишком большой payload');
      }
      // Other error - try next server
      return null;
    } catch (_) {
      // Connection error - try next server
      return null;
    }
  }

  static List<String> _trimToPayloadLimit(List<String> lines) {
    final trimmed = List<String>.from(lines);
    while (true) {
      final payloadSize = jsonEncode(trimmed).length;
      if (payloadSize < _maxPayloadBytes) return trimmed;
      if (trimmed.length <= 1) return trimmed;
      trimmed.removeAt(0);
    }
  }

  static List<String> _resolveServers() {
    try {
      final profile = globalState.config.currentProfile;
      final raw = profile?.providerHeaders[_serversHeaderName];
      if (raw != null && raw.isNotEmpty) {
        final servers = raw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (servers.isNotEmpty) return servers;
      }
    } catch (_) {}
    return const <String>[];
  }

  static Future<List<_LogRelayTarget>> _resolveRelayTargets(
    List<String> servers,
  ) async {
    final headerRelays = _resolveRelaysFromHeader();
    if (headerRelays.isNotEmpty) return headerRelays;
    return _resolveRelaysFromManifest(servers);
  }

  static List<_LogRelayTarget> _resolveRelaysFromHeader() {
    try {
      final profile = globalState.config.currentProfile;
      final raw = profile?.providerHeaders[_relaysHeaderName];
      if (raw == null || raw.isEmpty) return const <_LogRelayTarget>[];
      final relays = <_LogRelayTarget>[];
      for (final part in raw.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;
        final uri = Uri.tryParse(trimmed);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          continue;
        }
        relays.add(_LogRelayTarget.passthrough(trimmed));
      }
      return relays;
    } catch (_) {}
    return const <_LogRelayTarget>[];
  }

  static Future<List<_LogRelayTarget>> _resolveRelaysFromManifest(
    List<String> servers,
  ) async {
    final manifestUrl = _resolveManifestUrl();
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      LogBuffer.instance.add('[ParazitX][logs] invalid manifest URL');
      return const <_LogRelayTarget>[];
    }

    try {
      final response = await http.get(uri).timeout(_uploadTimeout);
      if (response.statusCode != 200) {
        LogBuffer.instance
            .add('[ParazitX][logs] manifest HTTP ${response.statusCode}');
        return const <_LogRelayTarget>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        LogBuffer.instance.add('[ParazitX][logs] manifest root invalid');
        return const <_LogRelayTarget>[];
      }
      final manifest = ParazitXManifest.fromJson(decoded);
      final relays = <_LogRelayTarget>[];
      final seen = <String>{};

      void add(ParazitXSignalingRelay relay) {
        if (!_isUsableManifestRelay(relay)) return;
        if (relay.kind == kParazitXRelayKindHttpsPassthrough &&
            servers.isEmpty) {
          return;
        }
        final key = '${relay.kind}|${relay.url}';
        if (!seen.add(key)) return;
        relays.add(_LogRelayTarget(
          url: relay.url,
          requiresBackendHeader:
              relay.kind == kParazitXRelayKindHttpsPassthrough,
        ));
      }

      // Session relays are standalone HTTPS endpoints and are exactly what
      // keeps log upload working when stale direct backend headers are gone.
      for (final relay in manifest.signalingRelays) {
        if (relay.kind == kParazitXRelayKindHttpsSession) add(relay);
      }

      // Passthrough relays can be used only when we still have a backend
      // from headers. Scope them to matching manifest nodes when possible.
      if (servers.isNotEmpty) {
        final serverSet = servers.toSet();
        for (final node in manifest.nodes) {
          final endpoint = '${node.host}:${node.port}';
          if (!serverSet.contains(endpoint)) continue;
          for (final relay in manifest.relaysForNode(node.id)) {
            add(relay);
          }
        }
      }

      if (relays.isNotEmpty) {
        LogBuffer.instance
            .add('[ParazitX][logs] manifest relays=${relays.length}');
      }
      return relays;
    } catch (e) {
      LogBuffer.instance.add('[ParazitX][logs] manifest relay lookup failed');
      return const <_LogRelayTarget>[];
    }
  }

  static String _resolveManifestUrl() {
    try {
      final profile = globalState.config.currentProfile;
      final raw = profile?.providerHeaders[_manifestHeaderName];
      final trimmed = raw?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    } catch (_) {}
    return _defaultManifestUrl;
  }

  static bool _isUsableManifestRelay(ParazitXSignalingRelay relay) {
    if (!kParazitXSupportedRelayKinds.contains(relay.kind)) return false;
    final uri = Uri.tryParse(relay.url.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static Future<LogUploadResult?> _tryUploadViaRelay(
    String relayUrl,
    String? backend,
    String payload,
    Duration timeout,
    DateTime now,
  ) async {
    try {
      final baseUri = Uri.tryParse(relayUrl);
      if (baseUri == null) return null;
      // Append /v1/logs to relay base URL
      final basePath = baseUri.path.endsWith('/')
          ? baseUri.path.substring(0, baseUri.path.length - 1)
          : baseUri.path;
      final uri = baseUri.replace(path: '$basePath/v1/logs');

      final headers = {
        'Content-Type': 'application/json',
        if (backend != null) _relayBackendHeaderName: backend,
      };

      final resp = await http
          .post(
            uri,
            headers: headers,
            body: payload,
          )
          .timeout(timeout);
      if (resp.statusCode == 200) {
        _lastUploadAt = now;
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final id = (data['id'] as String?) ?? 'ok';
          return LogUploadResult.ok(id);
        } catch (_) {
          return LogUploadResult.ok('ok');
        }
      }
      if (resp.statusCode == 429) {
        return LogUploadResult.err('Сервер: слишком часто (429)');
      }
      if (resp.statusCode == 413) {
        return LogUploadResult.err('Сервер: слишком большой payload');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> _resolveDeviceId() async {
    try {
      final details = await DeviceInfoService().getDeviceDetails();
      final hwid = details.hwid;
      if (hwid != null && hwid.isNotEmpty) return hwid;
    } catch (_) {}
    return 'unknown-device';
  }

  static Future<String> _resolveAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }
}

class _LogRelayTarget {
  const _LogRelayTarget({
    required this.url,
    required this.requiresBackendHeader,
  });

  const _LogRelayTarget.passthrough(String url)
      : this(url: url, requiresBackendHeader: true);

  final String url;
  final bool requiresBackendHeader;
}
