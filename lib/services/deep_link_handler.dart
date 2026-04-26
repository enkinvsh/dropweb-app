import 'dart:async';
import 'dart:developer' as developer;

import 'package:dropweb/common/navigator.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/parazitx_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class DeepLinkHandler {
  DeepLinkHandler._();

  static const _channel = MethodChannel('app.dropweb/navigation');
  static const _events = EventChannel('app.dropweb/navigation/events');
  static StreamSubscription<dynamic>? _sub;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _sub = _events.receiveBroadcastStream().listen(
      (route) {
        if (route is String) _navigate(route);
      },
      onError: (Object e) {
        developer.log('navigation event error: $e', name: 'DeepLink');
      },
    );

    try {
      final initial = await _channel.invokeMethod<String>('getInitialRoute');
      if (initial != null && initial.isNotEmpty) _navigate(initial);
    } on PlatformException catch (e) {
      developer.log('getInitialRoute failed: ${e.message}', name: 'DeepLink');
    } on MissingPluginException {
      // Non-Android platforms don't register the channel.
    }
  }

  static void _navigate(String route) {
    switch (route) {
      case 'parazitx':
        _openParazitX();
        break;
      default:
        developer.log('unknown route: $route', name: 'DeepLink');
    }
  }

  static void _openParazitX() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = globalState.navigatorKey.currentState;
      if (navigator == null) return;

      globalState.appController.toPage(PageLabel.tools);

      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        CommonRoute<void>(
          builder: (_) => const ParazitXPage(),
        ),
      );
    });
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
