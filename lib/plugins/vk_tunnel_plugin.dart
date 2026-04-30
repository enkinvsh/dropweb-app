import 'dart:async';

import 'package:flutter/services.dart';

/// Raw statuses emitted by librelay on stdout STATUS: lines.
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

/// Status stream from ParazitXVpnService.
///
/// Statuses originate in the `:parazitx` process (librelay stdout). The
/// service broadcasts them cross-process; MainActivity forwards to this
/// EventChannel. Multiple listeners (manager + captcha + UI) fan out off
/// a single broadcast controller because Flutter's EventChannel allows
/// only one native-side StreamHandler.
class VkTunnelPlugin {
  static const _statusChannel = EventChannel('app.dropweb/vktunnel/status');

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
}
