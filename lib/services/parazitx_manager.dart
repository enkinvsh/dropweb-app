import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  /// Platform channel to ParazitXVpnService for high-priority "Action
  /// Required" notification when captcha auto-solve stalls in background.
  static const _notificationChannel =
      MethodChannel('app.dropweb/parazitx_notifications');

  /// How long the headless WebView gets to auto-click the captcha before
  /// we surface a heads-up notification.
  ///
  /// Foreground: 10s — auto-solve usually wins.
  /// Background: 2s — Android throttles JS in hidden webviews so auto-solve
  /// won't progress; surface the notification ASAP so the user can bring
  /// the app to foreground (or fullScreenIntent wakes them on lock screen).
  static const _captchaForegroundPromptDelay = Duration(seconds: 10);
  static const _captchaBackgroundPromptDelay = Duration(seconds: 2);
  // TURN allocation lifetime is 10 minutes (RFC 5766 default) and VK's TURN
  // server doesn't honor refresh requests, while ICE restart doesn't work with
  // the VK SFU. The only reliable solution is to rotate to a new call BEFORE
  // the TURN allocation expires. 8 minutes gives a 2-minute safety margin.
  static const _rotationInterval = Duration(minutes: 8);
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

    // Register lifecycle observer so background-captcha logic can fire.
    _ensureLifecycleObserver();

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
        unawaited(_solveCaptchaAutomatically(captchaUrl));
        return;
      }

      if (TunnelStatus.isTunnelReady(status)) {
        if (!_tunnelReady) {
          _tunnelReady = true;
          _tunnelReadyCtrl.add(true);
        }
        // Reset backoff on successful tunnel connection
        if (_reconnectAttempt > 0) {
          developer.log(
            'Tunnel ready: resetting reconnect backoff (was attempt '
            '$_reconnectAttempt, ${_currentBackoff.inSeconds}s)',
            name: 'ParazitX',
          );
          LogBuffer.instance.add(
            'Tunnel ready: resetting reconnect backoff '
            '(attempt=$_reconnectAttempt)',
          );
          _reconnectAttempt = 0;
          _currentBackoff = _minBackoff;
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

  /// Headless WebView used to auto-click VK's "I'm not a robot" checkbox.
  /// Stays alive while the captcha page is loading, then is disposed once
  /// the relay accepts the token (or after a hard timeout) so we don't
  /// leak native resources between calls.
  static HeadlessInAppWebView? _captchaWebView;
  static String? _solvingCaptchaUrl;
  static Timer? _captchaTimeoutTimer;
  static Timer? _captchaForegroundPromptTimer;
  static bool _actionNotificationShown = false;
  static StreamSubscription<String>? _captchaStatusSub;

  /// URL of the captcha currently being auto-solved. Tracked separately
  /// from [_solvingCaptchaUrl] so the lifecycle observer can restart
  /// auto-solve when the app returns to foreground (after WebView JS was
  /// throttled in background).
  static String? _pendingCaptchaUrl;

  /// Tracks app foreground/background state for captcha prompt timing
  /// and auto-solve restart logic. Updated by [_ParazitXLifecycleObserver].
  static bool _isAppInForeground = true;

  /// Singleton lifecycle observer. Lazily registered on first [activate]
  /// call, unregistered on [deactivate]. Bridges Flutter's app lifecycle
  /// events into this otherwise-static manager.
  static _ParazitXLifecycleObserver? _lifecycleObserver;

  static void _ensureLifecycleObserver() {
    if (_lifecycleObserver != null) return;
    final observer = _ParazitXLifecycleObserver();
    _lifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  static void _removeLifecycleObserver() {
    final observer = _lifecycleObserver;
    if (observer == null) return;
    WidgetsBinding.instance.removeObserver(observer);
    _lifecycleObserver = null;
  }

  /// Called by [_ParazitXLifecycleObserver] when app lifecycle changes.
  /// On returning to foreground with a pending captcha, restart auto-solve
  /// because the previous WebView was likely throttled by Android.
  static void _onAppLifecycleStateChanged(AppLifecycleState state) {
    final wasForeground = _isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (_isAppInForeground && !wasForeground && _pendingCaptchaUrl != null) {
      developer.log(
        'App returned to foreground with pending captcha, '
        'restarting auto-solve',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
        'App foregrounded with pending captcha, restarting auto-solve',
      );
      _restartCaptchaAutoSolve();
    }
  }

  /// Dispose any in-flight WebView and re-spawn auto-solve for the same
  /// pending captcha URL. Used when the app comes back to foreground —
  /// the previous WebView's JS may have been frozen by Android Doze.
  static void _restartCaptchaAutoSolve() {
    final url = _pendingCaptchaUrl;
    if (url == null) return;

    unawaited(() async {
      // _disposeCaptchaWebView() clears _pendingCaptchaUrl, so re-set it
      // before re-entering _solveCaptchaAutomatically().
      await _disposeCaptchaWebView();
      _pendingCaptchaUrl = url;
      await _solveCaptchaAutomatically(url);
    }());
  }

  static Future<void> _showActionRequiredNotification() async {
    if (_actionNotificationShown) return;
    _actionNotificationShown = true;
    try {
      await _notificationChannel.invokeMethod<void>('showActionRequired');
    } on PlatformException catch (e) {
      developer.log('showActionRequired failed: ${e.message}',
          name: 'ParazitX');
      _actionNotificationShown = false;
    }
  }

  static Future<void> _dismissActionRequiredNotification() async {
    if (!_actionNotificationShown) return;
    _actionNotificationShown = false;
    try {
      await _notificationChannel.invokeMethod<void>('dismissActionRequired');
    } on PlatformException catch (e) {
      developer.log('dismissActionRequired failed: ${e.message}',
          name: 'ParazitX');
    }
  }

  /// Open a hidden InAppWebView, load the captcha proxy URL, and click the
  /// "I'm not a robot" checkbox automatically. The relay running on
  /// 127.0.0.1:NNNN intercepts the resulting `captchaNotRobot.check` call
  /// and proceeds with auth — so we never need to show UI to the user.
  ///
  /// The manual visible-WebView flow is kept as a fallback (UI listens to
  /// [captchaStream] and opens it) in case auto-solve fails or VK switches
  /// to a puzzle captcha.
  static Future<void> _solveCaptchaAutomatically(String url) async {
    // Avoid spinning up a second WebView for the same URL: VK may emit
    // CAPTCHA: repeatedly until the token is delivered.
    if (_solvingCaptchaUrl == url && _captchaWebView != null) {
      developer.log(
        'Auto-solve already running for $url, skipping',
        name: 'ParazitX',
      );
      return;
    }

    await _disposeCaptchaWebView();
    _solvingCaptchaUrl = url;
    _pendingCaptchaUrl = url;

    developer.log('Auto-solving captcha: $url', name: 'ParazitX');
    LogBuffer.instance.add('Auto-solving captcha: $url');

    const injectScript = '''
(function() {
  if (window.__parazitxAutoClickInstalled) return;
  window.__parazitxAutoClickInstalled = true;

  var attempts = 0;
  var maxAttempts = 40; // ~10s at 250ms

  function tryClick() {
    attempts++;
    var selectors = [
      'input[type="checkbox"]',
      '.vkc__Checkbox__input',
      '[class*="Checkbox__input"]',
      '[class*="checkbox"] input',
      'input[name*="captcha"]',
    ];
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (el) {
        try {
          el.click();
          console.log('[parazitx] clicked captcha selector:', selectors[i]);
          return true;
        } catch (e) {
          console.log('[parazitx] click failed:', e);
        }
      }
    }
    if (attempts < maxAttempts) {
      setTimeout(tryClick, 250);
    } else {
      console.log('[parazitx] gave up auto-click after', attempts, 'tries');
    }
    return false;
  }

  if (document.readyState === 'complete' ||
      document.readyState === 'interactive') {
    tryClick();
  } else {
    document.addEventListener('DOMContentLoaded', tryClick);
    window.addEventListener('load', tryClick);
  }
})();
''';

    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
      ),
      onLoadStop: (controller, _) async {
        developer.log(
          'Captcha page loaded, injecting click',
          name: 'ParazitX',
        );
        LogBuffer.instance.add('Captcha page loaded, injecting click');
        try {
          await controller.evaluateJavascript(source: injectScript);
        } catch (e) {
          developer.log('Captcha JS inject failed: $e', name: 'ParazitX');
        }
      },
      onReceivedError: (_, __, error) {
        developer.log(
          'Captcha WebView error: ${error.description}',
          name: 'ParazitX',
        );
        LogBuffer.instance.add('Captcha WebView error: ${error.description}');
      },
      onConsoleMessage: (_, message) {
        if (message.message.contains('parazitx')) {
          developer.log(
            'Captcha console: ${message.message}',
            name: 'ParazitX',
          );
        }
      },
    );

    _captchaWebView = webView;

    // Tear the WebView down as soon as the relay says the captcha was
    // solved (or the tunnel goes ready / fails). We only listen for the
    // duration of the auto-solve attempt so we don't fight the main
    // status subscription.
    await _captchaStatusSub?.cancel();
    _captchaStatusSub = VkTunnelPlugin.statusStream.listen((status) {
      if (status.startsWith('Captcha solved') ||
          TunnelStatus.isTunnelReady(status) ||
          TunnelStatus.isFailure(status)) {
        developer.log(
          'Captcha resolved by relay (status=$status), disposing WebView',
          name: 'ParazitX',
        );
        unawaited(_disposeCaptchaWebView());
      }
    });

    _captchaForegroundPromptTimer?.cancel();
    final promptDelay = _isAppInForeground
        ? _captchaForegroundPromptDelay
        : _captchaBackgroundPromptDelay;
    _captchaForegroundPromptTimer = Timer(promptDelay, () {
      if (_captchaWebView == null) return;
      developer.log(
        'Captcha unresolved after ${promptDelay.inSeconds}s '
        '(foreground=$_isAppInForeground), '
        'surfacing action-required notification',
        name: 'ParazitX',
      );
      LogBuffer.instance.add(
        'Captcha unresolved >${promptDelay.inSeconds}s '
        '(foreground=$_isAppInForeground), showing action notification',
      );
      unawaited(_showActionRequiredNotification());
    });

    // Hard timeout: 30s. If VK switched to a puzzle or our selectors
    // missed, the visible CaptchaScreen (subscribed to captchaStream)
    // remains as a fallback path for the user.
    _captchaTimeoutTimer = Timer(const Duration(seconds: 30), () {
      developer.log(
        'Auto-solve timeout for $url, disposing WebView',
        name: 'ParazitX',
      );
      LogBuffer.instance.add('Captcha auto-solve timeout');
      unawaited(_disposeCaptchaWebView());
    });

    try {
      await webView.run();
    } catch (e) {
      developer.log('Headless WebView run failed: $e', name: 'ParazitX');
      LogBuffer.instance.add('Headless WebView run failed: $e');
      await _disposeCaptchaWebView();
    }
  }

  static Future<void> _disposeCaptchaWebView() async {
    _captchaTimeoutTimer?.cancel();
    _captchaTimeoutTimer = null;
    _captchaForegroundPromptTimer?.cancel();
    _captchaForegroundPromptTimer = null;
    await _captchaStatusSub?.cancel();
    _captchaStatusSub = null;
    _solvingCaptchaUrl = null;
    _pendingCaptchaUrl = null;
    final wv = _captchaWebView;
    _captchaWebView = null;
    if (wv != null) {
      try {
        await wv.dispose();
      } catch (e) {
        developer.log('Failed to dispose captcha WebView: $e',
            name: 'ParazitX');
      }
    }
    await _dismissActionRequiredNotification();
  }

  /// Tear down the VpnService (which tears down relay + tun2socks
  /// internally) and clear local state.
  static Future<void> deactivate() async {
    _stopRotationTimer();
    _reconnectDebounce?.cancel();
    _reconnectDebounce = null;
    _reconnectAttempt = 0;
    _currentBackoff = _minBackoff;
    await _statusSub?.cancel();
    _statusSub = null;
    await _disposeCaptchaWebView();
    _removeLifecycleObserver();
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
    if (!_isActive) {
      developer.log('rotateCall: not active, skipping', name: 'ParazitX');
      return;
    }
    if (_servers.isEmpty) {
      developer.log('rotateCall: no servers, skipping', name: 'ParazitX');
      LogBuffer.instance.add('rotateCall: no servers, skipping');
      return;
    }

    final session = await _requestJoinLink();
    if (session.error != null) {
      developer.log(
        'Rotation failed: ${session.error}',
        name: 'ParazitX',
      );
      LogBuffer.instance.add('Rotation failed: ${session.error}');
      return;
    }

    final newJoinLink = session.joinLink!;
    developer.log('rotateCall: got new joinLink', name: 'ParazitX');

    try {
      await ParazitXVpnPlugin.start(
        joinLink: newJoinLink,
        socksPort: _socksPort,
      );
      _currentJoinLink = newJoinLink;
      _serverIndex = session.serverIndex!;
      developer.log('Rotation successful', name: 'ParazitX');
      LogBuffer.instance.add('Rotation successful, new call started');
    } on PlatformException catch (e) {
      developer.log('Rotation vpn start failed: ${e.message}',
          name: 'ParazitX');
      LogBuffer.instance.add('Rotation vpn start failed: ${e.message}');
    }
  }

  /// Debounce timer to prevent reconnect spam on rapid failures.
  static Timer? _reconnectDebounce;

  /// Minimum backoff delay before first reconnect attempt.
  static const _minBackoff = Duration(seconds: 2);

  /// Maximum backoff delay (cap) — exponential growth stops here.
  static const _maxBackoff = Duration(seconds: 60);

  /// Number of consecutive reconnect attempts since last successful tunnel.
  /// Reset to 0 in [_subscribeToRelayStatus] when tunnel becomes ready.
  static int _reconnectAttempt = 0;

  /// Current backoff delay. Doubles on each failure, capped at [_maxBackoff],
  /// resets to [_minBackoff] on successful tunnel connection.
  static Duration _currentBackoff = _minBackoff;

  /// Auto-reconnect after tunnel failure with exponential backoff.
  /// Delay sequence: 2s → 4s → 8s → 16s → 32s → 60s (capped).
  /// Resets to 2s on successful tunnel connection.
  static Future<void> _reconnectAfterFailure() async {
    _reconnectDebounce?.cancel();

    _reconnectAttempt += 1;
    final delay = _currentBackoff;

    developer.log(
      'Auto-reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempt)',
      name: 'ParazitX',
    );
    LogBuffer.instance.add(
      'Auto-reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempt)',
    );

    // Compute next backoff: double, capped at _maxBackoff.
    final nextSeconds = delay.inSeconds * 2;
    _currentBackoff = nextSeconds >= _maxBackoff.inSeconds
        ? _maxBackoff
        : Duration(seconds: nextSeconds);

    _reconnectDebounce = Timer(delay, () async {
      if (!_isActive) {
        developer.log('Reconnect aborted: not active', name: 'ParazitX');
        LogBuffer.instance.add('Reconnect aborted: not active');
        return;
      }

      developer.log('Auto-reconnect: attempting new session', name: 'ParazitX');
      LogBuffer.instance.add('Auto-reconnect: attempting new session');

      // Clear joinLink so we know if rotation actually succeeded
      final oldJoinLink = _currentJoinLink;
      _currentJoinLink = null;

      await _rotateCall();

      // If rotation didn't set a new joinLink, do full reactivate
      if (_currentJoinLink == null) {
        developer.log(
          'Reconnect: rotation failed, trying full reactivate',
          name: 'ParazitX',
        );
        LogBuffer.instance
            .add('Reconnect: rotation failed, trying full reactivate');
        _isActive = false;
        final error = await activate();
        if (error != null) {
          developer.log('Reconnect: full reactivate failed: $error',
              name: 'ParazitX');
          LogBuffer.instance.add('Reconnect: full reactivate failed: $error');
          // Restore old joinLink for next retry attempt
          _currentJoinLink = oldJoinLink;
        }
      } else {
        LogBuffer.instance.add('Reconnect: rotation successful');
      }
    });
  }
}

/// Bridges Flutter's [WidgetsBindingObserver] callbacks into the static
/// [ParazitXManager]. Registered while the tunnel is active; tells the
/// manager when the app moves between foreground and background so we
/// can adjust captcha-prompt timing and restart auto-solve after Doze.
class _ParazitXLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ParazitXManager._onAppLifecycleStateChanged(state);
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
