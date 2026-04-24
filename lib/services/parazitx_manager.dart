import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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

  static final StreamController<bool> _tunnelReadyCtrl =
      StreamController<bool>.broadcast();
  static final StreamController<String> _captchaCtrl =
      StreamController<String>.broadcast();

  static bool _tunnelReady = false;
  static bool get isTunnelReady => _tunnelReady;
  static Stream<bool> get tunnelReadyStream => _tunnelReadyCtrl.stream;
  static Stream<String> get captchaStream => _captchaCtrl.stream;

  static bool get isActive => _isActive;

  /// Activate ParazitX mode:
  /// 1. Load stored VK cookies
  /// 2. Encrypt them with X25519+AES-GCM (forward secrecy)
  /// 3. POST to callfactory → receive join_link
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

    final cookies = await VkAuthService.loadCookies();
    if (cookies == null) return ActivateError.noCookies;

    // Encrypt cookies for transport
    final encrypted = await CryptoService.encryptCookies(cookies);

    // Send to callfactory and request a session
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('http://31.57.105.213:8088/v1/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(encrypted),
      );
    } catch (_) {
      return ActivateError.networkError;
    }

    if (response.statusCode != 200) {
      final body = response.body.toLowerCase();
      if (body.contains('vk unauthorized') ||
          body.contains('timeout waiting')) {
        return ActivateError.vkUnauthorized;
      }
      return ActivateError.serverError;
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return ActivateError.serverError;
    }

    _currentJoinLink = data['join_link'] as String?;
    if (_currentJoinLink == null) return ActivateError.serverError;

    final tunnelResult = await VkTunnelPlugin.startTunnel(_currentJoinLink!);
    if (!tunnelResult.isSuccess) return ActivateError.tunnelError;

    _currentSession = tunnelResult.session;
    _isActive = true;
    _subscribeToRelayStatus();

    // In case librelay emitted STATUS:TUNNEL_CONNECTED before we subscribed
    // (fast path: cached session, no captcha), query once after subscription.
    // Idempotent — _startVpnLayer checks _vpnStarted internally.
    unawaited(_checkAlreadyConnected());

    _startRotationTimer();
    return null;
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
        if (_tunnelReady) {
          _tunnelReady = false;
          _tunnelReadyCtrl.add(false);
        }
      }
    });
  }

  /// Tear down in reverse order of bring-up: VpnService first (so the tun
  /// is gone before its downstream SOCKS5 listener disappears), then the
  /// librelay process, then local state.
  static Future<void> deactivate() async {
    _stopRotationTimer();
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

  static Future<void> _rotateCall() async {
    if (!_isActive) return;

    // Get new join_link
    final cookies = await VkAuthService.loadCookies();
    if (cookies == null) return;

    final encrypted = await CryptoService.encryptCookies(cookies);

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('http://31.57.105.213:8088/v1/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(encrypted),
      );
    } catch (_) {
      return;
    }

    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final newJoinLink = data['join_link'] as String?;

    if (newJoinLink == null || newJoinLink == _currentJoinLink) return;

    // Restart tunnel with new link
    await VkTunnelPlugin.stopTunnel();
    final result = await VkTunnelPlugin.startTunnel(newJoinLink);

    if (result.isSuccess) {
      _currentJoinLink = newJoinLink;
      _currentSession = result.session;
    }
  }
}
