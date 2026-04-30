/// Patches a decoded Mihomo (clash-meta) configuration so that all
/// Hysteria/Hysteria2 outbound proxies dial through a local SOCKS5 bridge
/// exposed by the ParazitX VPN service (callfactory → vk-tunnel →
/// hysteria2-vk pipeline).
///
/// Design constraints (from product architecture):
///
/// * Subscriptions (Remnawave) remain the source of truth for proxy
///   groups, rules, and rule-providers. We **never** reshape them.
/// * Only the bridge proxy entry is appended, and only Hysteria/Hysteria2
///   proxies receive the `dialer-proxy` field. Other proxy types are
///   untouched.
/// * The patcher is idempotent: applying it twice with a different bridge
///   port updates the existing entry instead of duplicating it.
/// * If a Hysteria/Hysteria2 proxy already has a non-Dropweb
///   `dialer-proxy`, we treat it as a user override and leave it alone,
///   reporting it as skipped.
///
/// The patcher is a pure function over `Map<String, dynamic>`; no IO,
/// no platform calls, no UI. Higher-level orchestration (when to patch,
/// where to get the bridge port) lives in `ParazitXManager`.
library;

/// Stable name of the local SOCKS5 bridge proxy injected into the
/// `proxies` array. The leading `__` makes it visually distinct from
/// user-named proxies and keeps it sorted at the bottom of most UIs.
const kDropwebParazitXBridgeName = '__dropweb_parazitx_vk_bridge';

/// Default loopback address for the bridge proxy. Overridable via
/// [MihomoDialerProxyPatcher.patch]'s `bridgeServer` argument for tests
/// or non-standard deployments.
const kDropwebParazitXBridgeServer = '127.0.0.1';

/// Mihomo proxy types that must be routed through the bridge.
const _patchableTypes = <String>{'hysteria', 'hysteria2'};

/// Why a particular proxy was skipped during patching.
enum SkipReason {
  /// Proxy already has a `dialer-proxy` set to something other than the
  /// Dropweb bridge — treated as a user override.
  userDialerProxy,
}

/// One skipped proxy entry, recorded for diagnostics/UI.
class SkippedProxy {
  const SkippedProxy({required this.name, required this.reason});

  final String name;
  final SkipReason reason;
}

/// Result of [MihomoDialerProxyPatcher.patch].
class MihomoPatchResult {
  const MihomoPatchResult({
    required this.bridgeAdded,
    required this.bridgeUpdated,
    required this.patchedCount,
    required this.skipped,
  });

  /// `true` when a new bridge proxy entry was inserted into `proxies`.
  /// Mutually exclusive with [bridgeUpdated].
  final bool bridgeAdded;

  /// `true` when an existing Dropweb bridge entry was updated in place
  /// (e.g. port changed). Mutually exclusive with [bridgeAdded].
  final bool bridgeUpdated;

  /// Number of Hysteria/Hysteria2 proxies that received a fresh
  /// `dialer-proxy` value pointing at the bridge.
  final int patchedCount;

  /// Proxies that were intentionally not patched, with reasons.
  final List<SkippedProxy> skipped;

  int get skippedCount => skipped.length;
}

/// Stateless utility class.
class MihomoDialerProxyPatcher {
  MihomoDialerProxyPatcher._();

  /// Mutates [config] in place. Returns a [MihomoPatchResult] summarising
  /// the changes for logging/diagnostics.
  ///
  /// The function does NOT touch `proxy-groups`, `rules`, `rule-providers`,
  /// `dns`, or `tun`. It only edits `proxies` and the entries within it.
  static MihomoPatchResult patch(
    Map<String, dynamic> config, {
    required int bridgePort,
    String bridgeServer = kDropwebParazitXBridgeServer,
  }) {
    // Ensure the proxies list exists and is mutable. Mihomo allows the
    // field to be absent on minimal configs.
    final rawProxies = config['proxies'];
    final List<dynamic> proxies;
    if (rawProxies is List) {
      proxies = rawProxies;
    } else {
      proxies = <dynamic>[];
      config['proxies'] = proxies;
    }

    // Step 1: bridge entry (insert or update in place).
    var bridgeAdded = false;
    var bridgeUpdated = false;
    Map<String, dynamic>? existingBridge;
    for (final p in proxies) {
      if (p is Map && p['name'] == kDropwebParazitXBridgeName) {
        existingBridge = p.cast<String, dynamic>();
        break;
      }
    }
    if (existingBridge == null) {
      proxies.add(<String, dynamic>{
        'name': kDropwebParazitXBridgeName,
        'type': 'socks5',
        'server': bridgeServer,
        'port': bridgePort,
      });
      bridgeAdded = true;
    } else {
      final hadDifferentValues = existingBridge['type'] != 'socks5' ||
          existingBridge['server'] != bridgeServer ||
          existingBridge['port'] != bridgePort;
      existingBridge['type'] = 'socks5';
      existingBridge['server'] = bridgeServer;
      existingBridge['port'] = bridgePort;
      bridgeUpdated = hadDifferentValues;
    }

    // Step 2: walk Hysteria/Hysteria2 proxies and attach dialer-proxy.
    var patchedCount = 0;
    final skipped = <SkippedProxy>[];
    for (final p in proxies) {
      if (p is! Map) continue;
      if (p['name'] == kDropwebParazitXBridgeName) continue;
      final type = p['type'];
      if (type is! String || !_patchableTypes.contains(type)) continue;

      final existingDialer = p['dialer-proxy'];
      if (existingDialer is String &&
          existingDialer.isNotEmpty &&
          existingDialer != kDropwebParazitXBridgeName) {
        // Respect user override.
        final name = p['name'];
        skipped.add(SkippedProxy(
          name: name is String ? name : '<unnamed>',
          reason: SkipReason.userDialerProxy,
        ));
        continue;
      }

      p['dialer-proxy'] = kDropwebParazitXBridgeName;
      patchedCount++;
    }

    return MihomoPatchResult(
      bridgeAdded: bridgeAdded,
      bridgeUpdated: bridgeUpdated && !bridgeAdded,
      patchedCount: patchedCount,
      skipped: List.unmodifiable(skipped),
    );
  }
}
