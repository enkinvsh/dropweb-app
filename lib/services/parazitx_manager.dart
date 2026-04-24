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

  /// VkTunnelPlugin.startTunnel() returned an error.
  tunnelError,
}

class ParazitXManager {
  static bool _isActive = false;
  static String? _currentJoinLink;
  static TunnelSession? _currentSession;
  static Timer? _rotationTimer;
  static StreamSubscription<String>? _statusSub;
  static bool _vpnStarted = false;
  static const _rotationInterval = Duration(minutes: 10);
  static const _sessionRequestTimeout = Duration(seconds: 35);

  /// Fallback when subscription does not provide a server list.
  /// Port 3478 matches the new callfactory (TURN mimicry).
  static const _fallbackServers = <String>['31.57.105.213:3478'];

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

  /// Activate ParazitX mode:
  /// 1. Load stored VK cookies
  /// 2. Encrypt them with X25519+AES-GCM (forward secrecy)
  /// 3. POST to callfactory → receive join_link (with 503/error fallback
  ///    across the server pool from the subscription)
  /// 4. Start VK SOCKS5 tunnel on 127.0.0.1:1080
  ///
  /// Returns null on success, or an [ActivateError] describing what went wrong.
  static Future<ActivateError?> activate() async {
    developer.log(
      'activate() called, isActive=$_isActive',
      name: 'ParazitX',
    );
    if (_isActive) return null;
    // Stale state from prior run — clean up before re-activating.
    if (_isActive) {
      developer.log('stale active state, forcing deactivate', name: 'ParazitX');
      await deactivate();
    }

    // Refresh server pool on every cold activate — subscription updates
    // after [deactivate] should propagate immediately.
    if (_servers.isEmpty) {
      _servers = await _loadServersFromSubscription();
      _servers.shuffle();
      _serverIndex = 0;
    }

    final cookies = await VkAuthService.loadCookies();
    if (cookies == null) return ActivateError.noCookies;

    final encrypted = await CryptoService.encryptCookies(cookies);
    final body = jsonEncode(encrypted);

    var lastError = ActivateError.networkError;

    // Try each server in order; on 503 or transient error move to the next.
    for (var attempt = 0; attempt < _servers.length; attempt++) {
      final idx = (_serverIndex + attempt) % _servers.length;
      final server = _servers[idx];
      developer.log('Trying server: $server', name: 'ParazitX');

      final http.Response response;
      try {
        response = await http
            .post(
              Uri.parse('http://$server/v1/session'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(_sessionRequestTimeout);
      } catch (e) {
        developer.log(
          'Server $server request failed: $e',
          name: 'ParazitX',
        );
        lastError = ActivateError.networkError;
        continue;
      }

      if (response.statusCode == 503) {
        developer.log(
          'Server $server overloaded (503), trying next',
          name: 'ParazitX',
        );
        lastError = ActivateError.serverError;
        continue;
      }

      if (response.statusCode != 200) {
        final respBody = response.body.toLowerCase();
        if (respBody.contains('vk unauthorized') ||
            respBody.contains('timeout waiting') ||
            respBody.contains('check cookies')) {
          // Auth problem is not server-specific — bail out immediately,
          // the user needs to re-login.
          return ActivateError.vkUnauthorized;
        }
        developer.log(
          'Server $server returned ${response.statusCode}: ${response.body}',
          name: 'ParazitX',
        );
        lastError = ActivateError.serverError;
        continue;
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        lastError = ActivateError.serverError;
        continue;
      }

      final joinLink = data['join_link'] as String?;
      if (joinLink == null) {
        lastError = ActivateError.serverError;
        continue;
      }

      _currentJoinLink = joinLink;

      final tunnelResult = await VkTunnelPlugin.startTunnel(joinLink);
      if (!tunnelResult.isSuccess) {
        // Tunnel failures are local (VpnService / librelay) — retrying
        // another callfactory won't help. Surface the error.
        return ActivateError.tunnelError;
      }

      _currentSession = tunnelResult.session;
      _isActive = true;
      // Remember the working server as the new starting point.
      _serverIndex = idx;
      _subscribeToRelayStatus();

      // In case librelay emitted STATUS:TUNNEL_CONNECTED before we subscribed
      // (fast path: cached session, no captcha), query once after subscription.
      // Idempotent — _startVpnLayer checks _vpnStarted internally.
      unawaited(_checkAlreadyConnected());

      _startRotationTimer();
      return null;
    }

    // Every server in the pool failed.
    developer.log(
      'All ${_servers.length} server(s) failed, lastError=$lastError',
      name: 'ParazitX',
    );
    return lastError;
  }

  static Future<void> _checkAlreadyConnected() async {
    try {
      final s = await VkTunnelPlugin.getStatus();
      print(
          '[ParazitX] _checkAlreadyConnected: status=$s tunnelReady=$_tunnelReady');
      if (TunnelStatus.isTunnelReady(s) && !_tunnelReady) {
        _tunnelReady = true;
        _tunnelReadyCtrl.add(true);
        unawaited(_startVpnLayer());
      }
    } on Exception catch (e) {
      print('[ParazitX] _checkAlreadyConnected error: $e');
    }
  }

  /// Starts the ParazitX VpnService once librelay reports TUNNEL_CONNECTED.
  /// Requires a pre-confirmed session (SOCKS credentials known) so
  /// [Androidbind.startTun2Socks] can attach to the right SOCKS5 listener.
  static Future<ActivateError?> _startVpnLayer() async {
    print(
        '[ParazitX] _startVpnLayer called, _vpnStarted=$_vpnStarted, session=${_currentSession?.socksPort}');
    if (_vpnStarted) return null;
    final s = _currentSession;
    if (s == null) {
      print('[ParazitX] _startVpnLayer: NO SESSION');
      return ActivateError.tunnelError;
    }
    try {
      print('[ParazitX] calling ParazitXVpnPlugin.start port=${s.socksPort}');
      await ParazitXVpnPlugin.start(
        socksPort: s.socksPort,
        socksUser: s.socksUser,
        socksPass: s.socksPass,
      );
      _vpnStarted = true;
      print('[ParazitX] VpnPlugin.start returned OK');
      return null;
    } on PlatformException catch (e) {
      print('[ParazitX] vpn start FAILED: ${e.code} ${e.message}');
      return ActivateError.tunnelError;
    } catch (e) {
      print('[ParazitX] vpn start UNEXPECTED: $e');
      return ActivateError.tunnelError;
    }
  }

  static void _subscribeToRelayStatus() {
    print('[ParazitX] subscribe called');
    _statusSub?.cancel();
    _statusSub = VkTunnelPlugin.statusStream.listen((status) {
      print('[ParazitX] relay status: $status');

      final captchaUrl = TunnelStatus.captchaUrl(status);
      if (captchaUrl != null) {
        _captchaCtrl.add(captchaUrl);
        return;
      }

      if (TunnelStatus.isTunnelReady(status)) {
        print('[ParazitX] TUNNEL_READY detected, _tunnelReady=$_tunnelReady');
        if (!_tunnelReady) {
          _tunnelReady = true;
          _tunnelReadyCtrl.add(true);
          unawaited(_startVpnLayer());
        }
      } else if (TunnelStatus.isFailure(status)) {
        print(
            '[ParazitX] TUNNEL FAILURE detected: $status, triggering reconnect');
        if (_tunnelReady) {
          _tunnelReady = false;
          _tunnelReadyCtrl.add(false);
        }
        // Auto-reconnect on tunnel failure
        unawaited(_reconnectAfterFailure());
      }
    });
  }

  /// Tear down in reverse order of bring-up: VpnService first (so the tun
  /// is gone before its downstream SOCKS5 listener disappears), then the
  /// librelay process, then local state.
  static Future<void> deactivate() async {
    _stopRotationTimer();
    _reconnectDebounce?.cancel();
    _reconnectDebounce = null;
    await _statusSub?.cancel();
    _statusSub = null;
    if (_vpnStarted) {
      try {
        await ParazitXVpnPlugin.stop();
      } on PlatformException catch (e) {
        developer.log('vpn stop failed: ${e.message}', name: 'ParazitX');
      }
      _vpnStarted = false;
    }
    try {
      await VkTunnelPlugin.stopTunnel();
    } on Exception catch (_) {
      // ignore — native may not be running
    }
    _isActive = false;
    _currentJoinLink = null;
    _currentSession = null;
    // Drop cached pool so the next activate picks up subscription updates.
    _servers = [];
    _serverIndex = 0;
    if (_tunnelReady) {
      _tunnelReady = false;
      _tunnelReadyCtrl.add(false);
    }
  }

  /// Returns tunnel status string.
  static Future<String> getStatus() async {
    if (!_isActive) return 'inactive';
    return VkTunnelPlugin.getStatus();
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

  /// Periodic rotation: ask callfactory for a new call and hand it to the
  /// relay. Tries the current server first, falls back across the pool on
  /// 503 / transient errors so a single overloaded node doesn't break the
  /// user's session.
  static Future<void> _rotateCall() async {
    if (!_isActive) return;
    if (_servers.isEmpty) return;

    final cookies = await VkAuthService.loadCookies();
    if (cookies == null) return;

    final encrypted = await CryptoService.encryptCookies(cookies);
    final body = jsonEncode(encrypted);

    for (var attempt = 0; attempt < _servers.length; attempt++) {
      final idx = (_serverIndex + attempt) % _servers.length;
      final server = _servers[idx];

      final http.Response response;
      try {
        response = await http
            .post(
              Uri.parse('http://$server/v1/session'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(_sessionRequestTimeout);
      } catch (e) {
        developer.log(
          'Rotation: $server failed: $e',
          name: 'ParazitX',
        );
        continue;
      }

      if (response.statusCode == 503) {
        developer.log(
          'Rotation: $server overloaded, trying next',
          name: 'ParazitX',
        );
        continue;
      }

      if (response.statusCode != 200) {
        developer.log(
          'Rotation: $server returned ${response.statusCode}',
          name: 'ParazitX',
        );
        continue;
      }

      final Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final newJoinLink = data['join_link'] as String?;
      if (newJoinLink == null || newJoinLink == _currentJoinLink) return;

      // Restart tunnel with new link.
      await VkTunnelPlugin.stopTunnel();
      final result = await VkTunnelPlugin.startTunnel(newJoinLink);

      if (result.isSuccess) {
        _currentJoinLink = newJoinLink;
        _currentSession = result.session;
        _serverIndex = idx;
        developer.log('Rotation successful on $server', name: 'ParazitX');
      }
      return;
    }

    developer.log(
      'Rotation: all ${_servers.length} server(s) failed, keeping current call',
      name: 'ParazitX',
    );
  }

  /// Debounce timer to prevent reconnect spam on rapid failures.
  static Timer? _reconnectDebounce;

  /// Auto-reconnect after tunnel failure with debounce.
  /// Waits 2 seconds to avoid rapid reconnect loops, then attempts
  /// to establish a new VK call session.
  static Future<void> _reconnectAfterFailure() async {
    // Cancel any pending reconnect
    _reconnectDebounce?.cancel();

    _reconnectDebounce = Timer(const Duration(seconds: 2), () async {
      if (!_isActive) {
        developer.log('Reconnect aborted: not active', name: 'ParazitX');
        return;
      }

      developer.log('Auto-reconnect: attempting new session', name: 'ParazitX');

      // Stop current tunnel first
      try {
        await VkTunnelPlugin.stopTunnel();
      } catch (_) {}

      // Reset tunnel ready state
      if (_tunnelReady) {
        _tunnelReady = false;
        _tunnelReadyCtrl.add(false);
      }

      // Try to get a new session (reuses _rotateCall logic)
      await _rotateCall();

      // If rotation failed, try full reactivation
      if (_currentJoinLink == null) {
        developer.log(
          'Reconnect: rotation failed, trying full reactivate',
          name: 'ParazitX',
        );
        _isActive = false; // Allow activate() to proceed
        await activate();
      }
    });
  }
}
