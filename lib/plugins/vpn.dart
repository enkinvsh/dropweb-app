import 'dart:async';
import 'dart:convert';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract mixin class VpnListener {
  void onDnsChanged(String dns) {}
}

class Vpn {
  factory Vpn() {
    _instance ??= Vpn._internal();
    return _instance!;
  }

  Vpn._internal() {
    methodChannel = const MethodChannel("vpn");
    methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case "gc":
          clashCore.requestGc();
        case "getStartForegroundParams":
          if (handleGetStartForegroundParams != null) {
            return await handleGetStartForegroundParams!();
          }
          // Default handler for UI mode - get current proxy name from core
          return _getDefaultForegroundParams();
        case "status":
          return clashLibHandler?.getRunTime() != null;
        default:
          for (final listener in _listeners) {
            switch (call.method) {
              case "dnsChanged":
                final dns = call.arguments as String;
                listener.onDnsChanged(dns);
            }
          }
      }
    });
  }
  static Vpn? _instance;
  late MethodChannel methodChannel;
  FutureOr<String> Function()? handleGetStartForegroundParams;

  /// Cached server name for foreground notification (updated via updateServerName)
  String _cachedServerName = "";

  /// Cached profile info for foreground notification
  String _cachedProfileName = "dropweb";
  String _cachedServiceName = "";

  /// Cached routing mode for foreground notification (updated via updateMode)
  Mode _cachedMode = Mode.rule;

  /// Update cached server name (called from UI when proxy changes)
  void updateServerName(String serverName) {
    _cachedServerName = serverName;
  }

  /// Update cached profile info (called when profile changes or on init)
  void updateProfileInfo({
    required String profileName,
    required String serviceName,
  }) {
    _cachedProfileName = profileName;
    _cachedServiceName = serviceName;
  }

  /// Update cached routing mode (called from UI when mode changes)
  void updateMode(Mode mode) {
    _cachedMode = mode;
  }

  /// Get cached server name
  String get cachedServerName => _cachedServerName;

  /// Get cached routing mode
  Mode get cachedMode => _cachedMode;

  /// Get cached profile name
  String get cachedProfileName => _cachedProfileName;

  /// Get cached service name
  String get cachedServiceName => _cachedServiceName;

  /// Decode base64 string if needed
  String? _decodeBase64IfNeeded(String? value) {
    if (value == null || value.isEmpty) return value;
    try {
      final normalized = base64.normalize(value);
      return utf8.decode(base64.decode(normalized));
    } catch (e) {
      return value;
    }
  }

  /// Default foreground params when running in UI mode.
  /// Shows: title = "Mode \u2022 Server", content = traffic, server (subText) = empty.
  String _getDefaultForegroundParams() {
    try {
      final traffic = clashCore.getTraffic();
      final profile = globalState.config.currentProfile;

      // Current routing mode (localized)
      final mode = globalState.config.patchClashConfig.mode;
      final modeLabel = switch (mode) {
        Mode.rule => appLocalizations.rule,
        Mode.global => appLocalizations.global,
        Mode.direct => appLocalizations.direct,
      };

      // Current proxy/server name
      String? proxyName;
      try {
        final serverInfoGroupName = _decodeBase64IfNeeded(
          profile?.providerHeaders['flclashx-serverinfo'],
        );
        if (serverInfoGroupName != null && serverInfoGroupName.isNotEmpty) {
          proxyName = globalState.appController
              .getSelectedProxyName(serverInfoGroupName);
        }
      } catch (_) {}

      final serverDisplay = (proxyName ?? "").trim();
      final title = serverDisplay.isNotEmpty
          ? "$modeLabel \u2022 $serverDisplay"
          : modeLabel;

      return json.encode({
        "title": title,
        "server": "",
        "content": "$traffic",
      });
    } catch (e) {
      return json.encode({
        "title": "dropweb",
        "server": "",
        "content": "",
      });
    }
  }

  final ObserverList<VpnListener> _listeners = ObserverList<VpnListener>();

  Future<bool?> start(AndroidVpnOptions options) async =>
      methodChannel.invokeMethod<bool>("start", {
        'data': json.encode(options),
      });

  Future<bool?> stop() async => methodChannel.invokeMethod<bool>("stop");

  /// Show subscription expiration notification
  Future<bool?> showSubscriptionNotification({
    required String title,
    required String message,
    required String actionLabel,
    required String actionUrl,
  }) async =>
      methodChannel.invokeMethod<bool>("showSubscriptionNotification", {
        'title': title,
        'message': message,
        'actionLabel': actionLabel,
        'actionUrl': actionUrl,
      });

  void addListener(VpnListener listener) {
    _listeners.add(listener);
  }

  void removeListener(VpnListener listener) {
    _listeners.remove(listener);
  }
}

Vpn? get vpn {
  // On Android, we always need Vpn instance to handle method channel calls
  // from the VPN service (e.g., getStartForegroundParams)
  if (defaultTargetPlatform == TargetPlatform.android) {
    return Vpn();
  }
  // On other platforms, only create in service mode
  return globalState.isService ? Vpn() : null;
}
