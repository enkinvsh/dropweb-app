import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../plugins/parazitx_vpn_plugin.dart';
import '../plugins/vk_tunnel_plugin.dart';
import 'crypto_service.dart';
import 'log_buffer.dart';
import 'vk_auth_service.dart';

/// Typed activation failure reasons.
enum ActivateError {
  /// No VK cookies stored — user needs to log in first.
  noCookies,

  /// HTTP request to callfactory failed (no network / timeout).
  networkError,

  /// Server returned a non-200 status that isn't vkUnauthorized.
  serverError,

  /// VK session is expired / invalid — server responded with
  /// "vk unauthorized" or "timeout waiting".
  vkUnauthorized,

  /// ParazitXVpnService.start() failed (VPN consent denied / prepare failed).
  tunnelError,
}

class ParazitXManager {
  static bool _isActive = false;
  static String? _currentJoinLink;
  static Timer? _rotationTimer;
  static StreamSubscription<String>? _statusSub;
  static const _socksPort = 1080;
  static const _rotationInterval = Duration(minutes: 10);
  static const _sessionRequestTimeout = Duration(seconds: 35);

  /// Fallback when subscription does not provide a server list.
  /// Port 3478 matches the new callfactory (TURN mimicry).
  static const _fallbackServers = <String>['31.57.105.213:3478'];

  /// Yandex.Cloud proxy for TSPU whitelist mode.
  /// Used as fallback when direct IP is blocked.
  static const String _ycProxyUrl =
      'https://d5da461207asfg6i1lmt.628pfjdx.apigw.yandexcloud.net';

  /// Name of the subscription HTTP header that lists callfactory endpoints.
  /// Must use the `dropweb-` prefix — the profile loader only accepts
  /// dropweb-* provider headers (see Profile.fetchFile in models/profile.dart).
  static const _serversHeaderName = 'dropweb-parazitx-servers';

  /// Ordered list of `host:port` endpoints for /v1/session requests.
  /// Populated from the subscription header on first [activate] call,
  /// shuffled once to spread load across the pool, and cached until
  /// [deactivate] clears it.
  static List<String> _servers = [];

  /// Index of the last known working server inside [_servers].
  /// Used as the starting point for rotation/fallback loops so we stick
  /// to a proven endpoint until it fails.
  static int _serverIndex = 0;

  static final StreamController<bool> _tunnelReadyCtrl =
      StreamController<bool>.broadcast();
  static final StreamController<String> _captchaCtrl =
      StreamController<String>.broadcast();

  static bool _tunnelReady = false;
  static bool get isTunnelReady => _tunnelReady;
  static Stream<bool> get tunnelReadyStream => _tunnelReadyCtrl.stream;
  static Stream<String> get captchaStream => _captchaCtrl.stream;

  static bool get isActive => _isActive;

  /// Read the callfactory endpoint pool from the active profile's
  /// provider headers. Falls back to [_fallbackServers] when the header
  /// is missing, empty, or the profile cannot be read.
  static Future<List<String>> _loadServersFromSubscription() async {
    try {
      final profile = globalState.config.currentProfile;
      if (profile == null) {
        developer.log(
          'No active profile, using fallback servers',
          name: 'ParazitX',
        );
        return List<String>.from(_fallbackServers);
      }

      final raw = profile.providerHeaders[_serversHeaderName];
      if (raw == null || raw.isEmpty) {
        developer.log(
          'No $_serversHeaderName header, using fallback',
          name: 'ParazitX',
        );
        return List<String>.from(_fallbackServers);
      }

      final servers = raw
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (servers.isEmpty) {
        return List<String>.from(_fallbackServers);
      }

      developer.log(
        'Loaded ${servers.length} server(s) from subscription',
        name: 'ParazitX',
      );
      return servers;
    } catch (e) {
      developer.log(
        'Failed to load servers from subscription: $e',
        name: 'ParazitX',
      );
      return List<String>.from(_fallbackServers);
    }
  }

  /// Try to obtain session from a single server endpoint.
  /// [server] can be 'host:port' (HTTP) or a full URL (HTTPS).
  /// Returns ok result on success, or error result on failure.
  static Future<_SessionResult> _tryServer(
    String server,
    String body, {
    required Duration timeout,
    bool isHttps = false,
  }) async {
    final uri = isHttps
        ? Uri.parse('$server/v1/session')
        : Uri.parse('http://$server/v1/session');

    developer.log('Trying server: $server', name: 'ParazitX');

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);
    } catch (e) {
      developer.log('Server $server request failed: $e', name: 'ParazitX');
      return const _SessionResult.err(ActivateError.networkError);
    }

    if (response.statusCode == 503) {
      developer.log(
        'Server $server overloaded (503), trying next',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    if (response.statusCode != 200) {
      final respBody = response.body.toLowerCase();
      if (respBody.contains('vk unauthorized') ||
          respBody.contains('timeout waiting') ||
          respBody.contains('check cookies')) {
        return const _SessionResult.err(ActivateError.vkUnauthorized);
      }
      developer.log(
        'Server $server returned ${response.statusCode}: ${response.body}',
        name: 'ParazitX',
      );
      return const _SessionResult.err(ActivateError.serverError);
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return const _SessionResult.err(ActivateError.serverError);
    }

    final joinLink = data['join_link'] as String?;
    if (joinLink == null) {
      return const _SessionResult.err(ActivateError.serverError);
    }

    return _SessionResult.ok(joinLink, 0);
  }

  /// POST encrypted VK cookies to callfactory and return the join_link,
  /// or an [ActivateError] describing what went wrong.
  /// Strategy: Try direct server with short timeout (3s) for TSPU detection,
  /// then fall back to YC proxy with longer timeout (30s) if direct fails.
  static Future<_SessionResult> _requestJoinLink() async {
    final cookies = await VkAuthService.loadCookies();
    if (cookies == null) {
      return const _SessionResult.err(ActivateError.noCookies);
    }

    final encrypted = await CryptoService.encryptCookies(cookies);
    final body = jsonEncode(encrypted);

    // Try direct server first with short timeout (TSPU detection)
    final directResult = await _tryServer(
      _fallbackServers[0],
      body,
      timeout: const Duration(seconds: 3),
      isHttps: false,
    );
    if (directResult.error == null ||
        directResult.error == ActivateError.vkUnauthorized) {
      return directResult;
    }

    developer.log(
      'Direct connection failed (${directResult.error}), trying YC proxy...',
      name: 'ParazitX',
    );

    // Fall back to YC proxy with longer timeout
    final proxyResult = await _tryServer(
      _ycProxyUrl,
      body,
      timeout: const Duration(seconds: 30),
      isHttps: true,
    );
    if (proxyResult.error == null) {
      return proxyResult;
    }

    // If proxy also fails, try remaining fallback servers
    var lastError = proxyResult.error ?? ActivateError.networkError;

    for (var attempt = 0; attempt < _servers.length; attempt++) {
      final idx = (_serverIndex + attempt) % _servers.length;
      final server = _servers[idx];

      final result = await _tryServer(
        server,
        body,
        timeout: _sessionRequestTimeout,
        isHttps: false,
      );

      if (result.error == null) {
        return _SessionResult.ok(result.joinLink!, idx);
      }

      if (result.error == ActivateError.vkUnauthorized) {
        return result;
      }

      lastError = result.error ?? ActivateError.networkError;
    }

    developer.log(
      'All fallback attempts failed, lastError=$lastError',
      name: 'ParazitX',
    );
    return _SessionResult.err(lastError);
  }

  /// Activate ParazitX mode:
  /// 1. Load stored VK cookies
  /// 2. Encrypt them with X25519+AES-GCM (forward secrecy)
  /// 3. POST to callfactory → receive join_link
  /// 4. Hand joinLink to ParazitXVpnService (in `:parazitx` process) which
  ///    owns the whole pipeline: spawns relay, waits for TUNNEL_CONNECTED,
  ///    brings up tun + tun2socks.
  ///
  /// Returns null on success, or an [ActivateError] describing what went wrong.
  static Future<ActivateError?> activate() async {
    developer.log('activate() called, isActive=$_isActive', name: 'ParazitX');
    LogBuffer.instance.add('activate() called, isActive=$_isActive');
    if (_isActive) return null;

    if (_servers.isEmpty) {
      _servers = await _loadServersFromSubscription();
      _servers.shuffle();
      _serverIndex = 0;
    }

    final session = await _requestJoinLink();
    if (session.error != null) {
      LogBuffer.instance.add('activate failed: ${session.error}');
      return session.error;
    }

    final joinLink = session.joinLink!;
    _currentJoinLink = joinLink;
    _serverIndex = session.serverIndex!;

    // Subscribe BEFORE start so we don't miss the first CONNECTING status
    // (the service broadcasts synchronously on startForegroundService).
    _subscribeToRelayStatus();

    try {
      await ParazitXVpnPlugin.start(
        joinLink: joinLink,
        socksPort: _socksPort,
      );
    } on PlatformException catch (e) {
      developer.log('vpn start failed: ${e.code} ${e.message}',
          name: 'ParazitX');
      LogBuffer.instance.add('vpn start failed: ${e.code} ${e.message}');
      await _statusSub?.cancel();
      _statusSub = null;
      return ActivateError.tunnelError;
    }

    _isActive = true;
    _startRotationTimer();
    return null;
  }

  static void _subscribeToRelayStatus() {
    LogBuffer.instance.attachNativeChannel();
    _statusSub?.cancel();
    _statusSub = VkTunnelPlugin.statusStream.listen((status) {
      developer.log('relay status: $status', name: 'ParazitX');
      LogBuffer.instance.add('status: $status');

      final captchaUrl = TunnelStatus.captchaUrl(status);
      if (captchaUrl != null) {
        _captchaCtrl.add(captchaUrl);
        return;
      }

      if (TunnelStatus.isTunnelReady(status)) {
        if (!_tunnelReady) {
          _tunnelReady = true;
          _tunnelReadyCtrl.add(true);
        }
      } else if (TunnelStatus.isFailure(status)) {
        developer.log(
          'tunnel failure: $status, scheduling reconnect',
          name: 'ParazitX',
        );
        if (_tunnelReady) {
          _tunnelReady = false;
          _tunnelReadyCtrl.add(false);
        }
        unawaited(_reconnectAfterFailure());
      }
    });
  }

  /// Tear down the VpnService (which tears down relay + tun2socks
  /// internally) and clear local state.
  static Future<void> deactivate() async {
    _stopRotationTimer();
    _reconnectDebounce?.cancel();
    _reconnectDebounce = null;
    await _statusSub?.cancel();
    _statusSub = null;
    try {
      await ParazitXVpnPlugin.stop();
    } on PlatformException catch (e) {
      developer.log('vpn stop failed: ${e.message}', name: 'ParazitX');
    }
    _isActive = false;
    _currentJoinLink = null;
    _servers = [];
    _serverIndex = 0;
    if (_tunnelReady) {
      _tunnelReady = false;
      _tunnelReadyCtrl.add(false);
    }
  }

  /// Returns last known tunnel status from the live stream. The service
  /// owns the authoritative state — ask for a rebroadcast by re-listening
  /// (the native EventChannel does so automatically on first listener).
  static String getStatus() {
    if (!_isActive) return 'inactive';
    return _tunnelReady
        ? TunnelStatus.tunnelConnected
        : TunnelStatus.connecting;
  }

  static void _startRotationTimer() {
    _stopRotationTimer();
    _rotationTimer = Timer.periodic(_rotationInterval, (_) async {
      await _rotateCall();
    });
  }

  static void _stopRotationTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  /// Periodic rotation: ask callfactory for a new join_link and hand it to
  /// the running VpnService (which forwards it to relay as a fresh AUTH,
  /// reusing the same process + tun).
  static Future<void> _rotateCall() async {
    if (!_isActive) return;
    if (_servers.isEmpty) return;

    final session = await _requestJoinLink();
    if (session.error != null) {
      developer.log(
        'Rotation failed: ${session.error}, keeping current call',
        name: 'ParazitX',
      );
      return;
    }

    final newJoinLink = session.joinLink!;
    if (newJoinLink == _currentJoinLink) return;

    try {
      await ParazitXVpnPlugin.start(
        joinLink: newJoinLink,
        socksPort: _socksPort,
      );
      _currentJoinLink = newJoinLink;
      _serverIndex = session.serverIndex!;
      developer.log('Rotation successful', name: 'ParazitX');
    } on PlatformException catch (e) {
      developer.log('Rotation vpn start failed: ${e.message}',
          name: 'ParazitX');
    }
  }

  /// Debounce timer to prevent reconnect spam on rapid failures.
  static Timer? _reconnectDebounce;

  /// Auto-reconnect after tunnel failure with debounce.
  /// Waits 2 seconds to avoid rapid reconnect loops, then attempts to
  /// establish a new VK call session.
  static Future<void> _reconnectAfterFailure() async {
    _reconnectDebounce?.cancel();

    _reconnectDebounce = Timer(const Duration(seconds: 2), () async {
      if (!_isActive) {
        developer.log('Reconnect aborted: not active', name: 'ParazitX');
        return;
      }

      developer.log('Auto-reconnect: attempting new session', name: 'ParazitX');

      await _rotateCall();

      if (_currentJoinLink == null) {
        developer.log(
          'Reconnect: rotation failed, trying full reactivate',
          name: 'ParazitX',
        );
        _isActive = false;
        await activate();
      }
    });
  }
}

class _SessionResult {
  const _SessionResult.ok(String link, int idx)
      : joinLink = link,
        serverIndex = idx,
        error = null;
  const _SessionResult.err(ActivateError err)
      : joinLink = null,
        serverIndex = null,
        error = err;

  final String? joinLink;
  final int? serverIndex;
  final ActivateError? error;
}
