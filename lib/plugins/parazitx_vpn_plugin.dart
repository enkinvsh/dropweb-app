import 'package:flutter/services.dart';

class ParazitXVpnPlugin {
  static const _channel = MethodChannel('app.dropweb/parazitx_vpn');

  /// Conservative default MTU for the ParazitX tun. The dataplane is
  /// effectively WebRTC DataChannel/TURN, whose path MTU is closer to
  /// 1200–1280 than to a wired Ethernet 1500. Using 1500 caused IP
  /// fragmentation and silent reassembly drops for large UDP/TCP
  /// segments. 1280 is the IPv6 minimum MTU and a known-safe baseline
  /// for tunneled WebRTC paths.
  static const int defaultMtu = 1280;

  /// Starts the ParazitX VpnService. The service (in `:parazitx` process)
  /// owns the whole pipeline: spawns librelay, waits for TUNNEL_CONNECTED,
  /// then establishes tun + tun2socks. Relay inheriting the service's
  /// cgroup is what keeps it alive when the app is backgrounded.
  ///
  /// [mtu] sets both the VpnService.Builder MTU and the value passed to
  /// `Androidbind.startTun2Socks` so the kernel and tun2socks agree.
  /// Defaults to [defaultMtu] (1280); the native layer additionally
  /// clamps to a sane range and falls back to 1280 on out-of-range input.
  static Future<void> start({
    required String joinLink,
    int socksPort = 1080,
    int mtu = defaultMtu,
  }) async {
    await _channel.invokeMethod<void>('start', {
      'joinLink': joinLink,
      'socksPort': socksPort,
      'mtu': mtu,
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
