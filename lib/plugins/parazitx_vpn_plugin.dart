import 'package:flutter/services.dart';

class ParazitXVpnPlugin {
  static const _channel = MethodChannel('app.dropweb/parazitx_vpn');

  /// Starts the ParazitX VpnService. The service (in `:parazitx` process)
  /// owns the whole pipeline: spawns librelay, waits for TUNNEL_CONNECTED,
  /// then establishes tun + tun2socks. Relay inheriting the service's
  /// cgroup is what keeps it alive when the app is backgrounded.
  static Future<void> start({
    required String joinLink,
    int socksPort = 1080,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'joinLink': joinLink,
      'socksPort': socksPort,
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
