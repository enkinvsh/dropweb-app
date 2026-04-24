import 'dart:convert';

import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/device_info_service.dart';
import 'log_buffer.dart';

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
  static const _fallbackServers = <String>['31.57.105.213:3478'];
  static const _serversHeaderName = 'dropweb-parazitx-servers';
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

    final servers = _resolveServers();
    String? lastErr;
    for (final server in servers) {
      try {
        final resp = await http
            .post(
              Uri.parse('http://$server/v1/logs'),
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(_uploadTimeout);
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
          return LogUploadResult.err(
            'Сервер: слишком часто (429)',
          );
        }
        if (resp.statusCode == 413) {
          return LogUploadResult.err('Сервер: слишком большой payload');
        }
        lastErr = 'HTTP ${resp.statusCode}';
      } catch (e) {
        lastErr = e.toString();
      }
    }
    return LogUploadResult.err(lastErr ?? 'Все серверы недоступны');
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
    return List<String>.from(_fallbackServers);
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
