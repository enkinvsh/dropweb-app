import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/vk_auth_service.dart';

class VkLoginScreen extends StatefulWidget {
  /// If [clearFirst] is true the screen shows a spinner, wipes all VK cookies,
  /// then loads the WebView. Useful when the caller knows the existing session
  /// is stale and wants a guaranteed clean slate.
  ///
  /// Default is false — just open the WebView as-is (caller already took care
  /// of any required cleanup).
  const VkLoginScreen({super.key, this.clearFirst = false});

  final bool clearFirst;

  @override
  State<VkLoginScreen> createState() => _VkLoginScreenState();
}

class _VkLoginScreenState extends State<VkLoginScreen> {
  bool _isLoading = true;

  /// Whether the WebView is ready to be displayed.
  /// False only while [clearFirst] cookie wipe is in progress.
  bool _ready = false;

  InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.clearFirst) {
      VkAuthService.clearCookies().whenComplete(() {
        if (mounted) setState(() => _ready = true);
      });
    } else {
      _ready = true;
    }
  }

  /// Clear cookies and reload to a fresh login page.
  /// Called by the Refresh button in the AppBar.
  Future<void> _resetSession() async {
    setState(() {
      _ready = false;
    });
    await VkAuthService.clearCookies();
    if (!mounted) return;
    await _controller?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri('https://vk.com/login?no_mobile=1'),
      ),
    );
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Войти в VK'),
        actions: [
          IconButton(
            tooltip: 'Обновить вход',
            icon: const Icon(Icons.refresh),
            onPressed: _resetSession,
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: InAppWebView(
        onWebViewCreated: (c) => _controller = c,
        initialUrlRequest: URLRequest(
          // no_mobile=1 forces VK to stay on desktop (vk.com) instead of
          // redirecting to m.vk.com. Mobile session cookies include
          // remixmdevice/remixmvk-fp markers that make web_token fail
          // with "unauthorized" when used from a desktop-UA server.
          url: WebUri('https://vk.com/login?no_mobile=1'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
          // MUST match the UA used by the server-side headless-vk-creator;
          // VK fingerprint-binds the session to the UA, so a mismatch
          // causes web_token to fail with "unauthorized".
          userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/135.0.0.0 Safari/537.36',
        ),
        onLoadStart: (controller, url) => setState(() {
          _isLoading = true;
        }),
        onLoadStop: (controller, url) async {
          setState(() => _isLoading = false);

          final currentUrl = url?.toString() ?? '';
          debugPrint('[VkLogin] onLoadStop url=$currentUrl');

          // Accept any VK post-login page (desktop OR mobile).
          // Fighting VK's mobile-detection caused an infinite redirect
          // loop. We take whatever cookies VK gives us and move on.
          final isLoggedIn = (currentUrl.startsWith('https://vk.com/') ||
                  currentUrl.startsWith('https://m.vk.com/')) &&
              !currentUrl.contains('/login') &&
              !currentUrl.contains('login.php');
          if (!isLoggedIn) return;

          // Capture context-dependent objects before async gaps.
          final nav = Navigator.of(context);

          // Let VK finish any XHR that sets additional cookies
          // (httoken, remixgp etc. are often set via AJAX after load).
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          if (!mounted) return;

          final cookies = await VkAuthService.extractCookies();
          debugPrint(
            '[VkLogin] extracted cookies: ${cookies?.length ?? 0} chars, '
            'count=${cookies?.split('; ').length ?? 0}',
          );

          if (!mounted) return;
          if (cookies != null) {
            nav.pop(true);
          }
          // Else: cookies missing — keep the screen open without any
          // intrusive overlay. The user can retry via the AppBar refresh
          // button ("Обновить вход").
        },
      ),
    );
  }
}
