import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';

class DropwebHttpOverrides extends HttpOverrides {
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
    client.badCertificateCallback = (_, __, ___) => true;
    client.findProxy = handleFindProxy;
    return client;
  }
}
