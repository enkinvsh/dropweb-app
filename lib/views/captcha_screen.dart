import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../plugins/vk_tunnel_plugin.dart';

class CaptchaScreen extends StatefulWidget {
  const CaptchaScreen({super.key, required this.proxyUrl});

  final String proxyUrl;

  @override
  State<CaptchaScreen> createState() => _CaptchaScreenState();
}

class _CaptchaScreenState extends State<CaptchaScreen> {
  bool _loading = true;
  StreamSubscription<String>? _statusSub;

  @override
  void initState() {
    super.initState();
    _statusSub = VkTunnelPlugin.statusStream.listen((status) {
      if (!mounted) return;
      if (TunnelStatus.isTunnelReady(status)) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('VK запросил капчу'),
          actions: [
            if (_loading)
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
          initialUrlRequest: URLRequest(url: WebUri(widget.proxyUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            transparentBackground: true,
          ),
          onLoadStart: (_, __) => setState(() => _loading = true),
          onLoadStop: (_, __) => setState(() => _loading = false),
          onLoadError: (_, __, ___, ____) => setState(() => _loading = false),
        ),
      );
}
