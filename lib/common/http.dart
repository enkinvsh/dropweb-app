import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';

class DropwebHttpOverrides extends HttpOverrides {
  /// Hosts that are permitted to use self-signed / invalid certificates.
  /// Only the local mihomo helper + control API is allowed — everything else
  /// (subscription servers, update checks, IP detection APIs) MUST present
  /// a valid certificate chain.
  static const _localhostHosts = {'localhost', '127.0.0.1', '::1'};

  static String handleFindProxy(Uri url) {
    if ([localhost].contains(url.host)) {
      return "DIRECT";
    }

    // Mobile: app excluded from VPN, always go direct
    if (Platform.isAndroid || Platform.isIOS) {
      return "DIRECT";
    }

    // Desktop: use proxy when VPN is running (for subscription updates via VPN)
    final port = globalState.config.patchClashConfig.mixedPort;
    final isStart = globalState.appState.runTime != null;
    commonPrint.log("find $url proxy:$isStart");
    if (!isStart) return "DIRECT";
    return "PROXY localhost:$port";
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // SECURITY: Previously we accepted ANY certificate globally. That
    // exposed every subscription / API / update fetch to MITM.
    // Now we only accept bad certs for localhost (where the helper service
    // uses a self-signed cert, or plain cleartext for the mihomo control port).
    client.badCertificateCallback = (cert, host, port) {
      return _localhostHosts.contains(host);
    };
    client.findProxy = handleFindProxy;
    return client;
  }
}
