import 'dart:async';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStateManager extends ConsumerStatefulWidget {
  const AppStateManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(layoutChangeProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (prev != next) {
          globalState.cacheHeightMap = {};
        }
      });
    });
    ref.listenManual(
      checkIpProvider,
      (prev, next) {
        if (prev != next && next.b) {
          detectionState.startCheck();
        }
      },
      fireImmediately: true,
    );
    ref.listenManual(configStateProvider, (prev, next) {
      if (prev != next) {
        globalState.appController.savePreferencesDebounce();
      }
    });
    ref.listenManual(
      autoSetSystemDnsStateProvider,
      (prev, next) async {
        if (prev == next) {
          return;
        }
        if (next.a == true && next.b == true) {
          system.setMacOSDns(false);
        } else {
          system.setMacOSDns(true);
        }
      },
    );
  }

  @override
  void reassemble() {
    super.reassemble();
  }

  @override
  void dispose() {
    // ROBUSTNESS: dispose() must be synchronous. Previously it was marked
    // `async void`, which meant `await system.setMacOSDns(true)` was never
    // actually awaited by Flutter — DNS was NOT guaranteed to be reset
    // before the widget got torn down. We now fire-and-forget the reset
    // while keeping the observer removal synchronous so lifecycle contracts
    // aren't violated. `unawaited()` is the right primitive here: the error
    // path is just a log and we don't block dispose on networksetup I/O.
    unawaited(system.setMacOSDns(true));
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log("$state");
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      globalState.appController.savePreferencesDebounce();
    } else if (state == AppLifecycleState.resumed) {
      render?.resume();
      // BUGFIX: when the user toggled the VPN from the QS tile or the
      // foreground notification while this Flutter isolate was backgrounded,
      // the connect button stayed in its old state because we never pulled
      // the native runtime back. Sync on every resume so the FAB matches
      // reality.
      unawaited(globalState.appController.syncRunStateFromNative());
    } else {
      render?.resume();
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.appController.updateBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerHover: (_) {
          render?.resume();
        },
        child: widget.child,
      );
}

class AppEnvManager extends StatelessWidget {
  const AppEnvManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
