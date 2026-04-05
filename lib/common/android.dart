import 'dart:io';

import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/state.dart';

class Android {
  Future<void> init() async {
    app?.onExit = () async {
      await globalState.appController.savePreferences();
    };
  }
}

final android = Platform.isAndroid ? Android() : null;
