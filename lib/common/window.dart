import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class Window {
  Future<void> init(int version) async {
    final props = globalState.config.windowProps;
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    if (Platform.isWindows) {
      // One-time cleanup for users who were running a previous dropweb build
      // that unconditionally overwrote flclash:// and clashx:// handlers.
      // If the current handler still points to our exe, remove it so the
      // scheme becomes unclaimed — letting FlClashX (or any other app) take
      // it back on its next launch. No-op if the handler points elsewhere.
      await _migrateHijackedSchemes();

      // Always claim our own scheme.
      protocol.register("dropweb");

      // Claim common schemes only if no other app currently owns them.
      // This lets users without FlClashX still open flclash:// links in
      // dropweb, while leaving FlClashX-owned handlers untouched.
      protocol.register("flclash", onlyIfMissing: true);
      protocol.register("clashx", onlyIfMissing: true);
    }

    // On macOS, the app runs in status bar with popover - no window manager needed
    if (Platform.isMacOS) {
      return;
    }

    await windowManager.ensureInitialized();
    // Width is clamped to 600px on Windows by a Win32 WM_GETMINMAXINFO hook
    // in windows/runner/flutter_window.cpp (window_manager.setMaximumSize is
    // unreliable on frameless windows). The Dart-side clamp here only
    // protects against a stored windowProps.width > 600 from previous
    // releases — fresh installs never hit it.
    final clampedWidth = props.width.clamp(380.0, 600.0);
    final windowOptions = WindowOptions(
      size: Size(clampedWidth, props.height),
      minimumSize: const Size(380, 400),
      maximumSize: const Size(600, 99999),
    );
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    if (!Platform.isMacOS) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      final right = left + props.width;
      final bottom = top + props.height;
      if (left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        final displays = await screenRetriever.getAllDisplays();
        final isPositionValid = displays.any(
          (display) {
            final displayBounds = Rect.fromLTWH(
              display.visiblePosition!.dx,
              display.visiblePosition!.dy,
              display.size.width,
              display.size.height,
            );
            return displayBounds.contains(Offset(left, top)) ||
                displayBounds.contains(Offset(right, bottom));
          },
        );
        if (isPositionValid) {
          await windowManager.setPosition(
            Offset(
              left,
              top,
            ),
          );
        }
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setPreventClose(true);
    });
  }

  Future<void> show() async {
    if (Platform.isMacOS) return;

    render?.resume();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
  }

  Future<bool> get isVisible async {
    if (Platform.isMacOS) return false;

    final value = await windowManager.isVisible();
    commonPrint.log("window visible check: $value");
    return value;
  }

  Future<void> close() async {
    exit(0);
  }

  Future<void> hide() async {
    if (Platform.isMacOS) return;

    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  static const _migrationPrefKey = 'windows_protocol_cleanup_v1';

  /// Runs once per install. Removes our own claims on flclash:// and clashx://
  /// so [Protocol.register] with `onlyIfMissing: true` can see them as free.
  /// Guarded by a SharedPreferences flag so repeated launches don't churn the
  /// registry. Safe to call on every launch.
  Future<void> _migrateHijackedSchemes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationPrefKey) == true) return;
      protocol.unregisterIfOurs('flclash');
      protocol.unregisterIfOurs('clashx');
      await prefs.setBool(_migrationPrefKey, true);
    } catch (_) {
      // Migration is best-effort. A failure here just means the user keeps
      // the hijacked handler — they can reinstall to retry. Do not crash.
    }
  }
}

final window = system.isDesktop ? Window() : null;
