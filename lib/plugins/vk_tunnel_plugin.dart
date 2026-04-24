import 'dart:async';

import 'package:flutter/services.dart';

class TunnelSession {
  const TunnelSession({
    required this.socksPort,
    required this.socksUser,
    required this.socksPass,
  });

  final int socksPort;
  final String socksUser;
  final String socksPass;
}

class TunnelStartResult {
  const TunnelStartResult.success(this.session) : error = null;
  const TunnelStartResult.failure(this.error) : session = null;

  final TunnelSession? session;
  final String? error;

  bool get isSuccess => session != null;
}

/// Raw statuses emitted by librelay process on stdout STATUS: lines.
/// Mirrors bypass.whitelist.tunnel.VpnStatus from kulikov0.
abstract class TunnelStatus {
  static const ready = 'READY';
  static const connecting = 'CONNECTING';
  static const fetchingConfig = 'Fetching config...';
  static const tunnelConnected = 'TUNNEL_CONNECTED';
  static const tunnelLost = 'TUNNEL_LOST';
  static const callFailed = 'CALL_FAILED';

  static bool isTunnelReady(String s) =>
      s == tunnelConnected || s == 'TUNNEL_ACTIVE';

  static bool isFailure(String s) =>
      s.startsWith('ERROR:') || s == callFailed || s == tunnelLost;

  /// Relay emits "CAPTCHA:http://127.0.0.1:NNNN/" while blocked on VK captcha.
  /// Returns the URL, or null if the status is not a captcha request.
  static String? captchaUrl(String s) =>
      s.startsWith('CAPTCHA:') ? s.substring('CAPTCHA:'.length) : null;
}

class VkTunnelPlugin {
  static const _channel = MethodChannel('app.dropweb/vktunnel');
  static const _statusChannel = EventChannel('app.dropweb/vktunnel/status');

  // The native EventChannel handler can hold only one StreamHandler at a
  // time — every fresh receiveBroadcastStream().listen() causes onListen
  // to overwrite the previous handler. We fan out a single underlying
  // subscription into a process-wide broadcast controller so that
  // ParazitXManager and CaptchaScreen can both observe the same statuses.
  static StreamController<String>? _bus;

  static Stream<String> get statusStream {
    var bus = _bus;
    if (bus != null) return bus.stream;
    bus = StreamController<String>.broadcast(
      onCancel: () {
        // Keep the underlying native channel alive; we never close it.
      },
    );
    _statusChannel.receiveBroadcastStream().listen(
          (event) => bus!.add(event?.toString() ?? ''),
          onError: (Object e) => bus!.addError(e),
        );
    _bus = bus;
    return bus.stream;
  }

  static Future<TunnelStartResult> startTunnel(
    String joinLink, {
    int port = 1080,
  }) async {
    try {
      final res = await _channel.invokeMethod<dynamic>('startTunnel', {
        'joinLink': joinLink,
        'socksPort': port.toString(),
      });
      if (res is! Map) {
        return const TunnelStartResult.failure('bad response from native');
      }
      return TunnelStartResult.success(
        TunnelSession(
          socksPort: (res['socksPort'] as num?)?.toInt() ?? port,
          socksUser: res['socksUser'] as String? ?? '',
          socksPass: res['socksPass'] as String? ?? '',
        ),
      );
    } on PlatformException catch (e) {
      return TunnelStartResult.failure(e.message ?? e.code);
    }
  }

  static Future<void> stopTunnel() async {
    await _channel.invokeMethod('stopTunnel');
  }

  static Future<String> getStatus() async {
    final s = await _channel.invokeMethod<String>('getStatus');
    return s ?? 'unknown';
  }
}
