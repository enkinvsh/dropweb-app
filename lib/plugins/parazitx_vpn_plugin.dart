import 'package:flutter/services.dart';

class ParazitXVpnPlugin {
  static const _channel = MethodChannel('app.dropweb/parazitx_vpn');

  static Future<void> start({
    required int socksPort,
    required String socksUser,
    required String socksPass,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'socksPort': socksPort,
      'socksUser': socksUser,
      'socksPass': socksPass,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod<void>('stop');
  }

  static Future<bool> isRunning() async {
    final res = await _channel.invokeMethod<bool>('isRunning');
    return res ?? false;
  }
}
