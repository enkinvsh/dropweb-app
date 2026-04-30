/// ParazitX backend manifest model + node selection.
///
/// The manifest is a small JSON document, served by Dropweb infrastructure,
/// listing ParazitX transport-backend nodes (callfactory + vk-tunnel +
/// hysteria2-vk). It is the single source of truth for *backend* nodes —
/// distinct from Remnawave, which remains the source of *user* Hysteria/
/// Hysteria2 proxy nodes.
///
/// This file is intentionally UI-free, network-free, and platform-free so
/// it can be unit-tested in isolation. Fetching, caching, and integration
/// with `ParazitXManager` are handled by callers in later wiring tasks.
library;

/// Protocol identifier for the current callfactory/vk-bridge backend.
const kParazitXProtocolV1 = 'parazitx-callfactory-v1';

/// Required features for a node to be considered usable by the current
/// client. New required features can be appended without bumping the
/// protocol identifier; missing-but-newer features simply mean this client
/// does not see the node as compatible.
const kParazitXRequiredFeatures = <String>['session-v1', 'socks5-local'];

/// Signaling-relay kinds the current client knows how to dial.
///
/// `https-passthrough` — generic forwarder. Relay accepts the same
/// `/v1/session` POST body as the backend node, but over HTTPS, and
/// forwards to the backend specified by an `X-Dropweb-Backend: host:port`
/// header that the client supplies. Use when the relay does not itself
/// know which backend to talk to.
const kParazitXRelayKindHttpsPassthrough = 'https-passthrough';

/// `https-session` — relay IS a session endpoint. The client POSTs the
/// same encrypted body to `${relay.url}/v1/session` directly, with NO
/// `X-Dropweb-Backend` header. The relay (e.g. a Yandex API Gateway in
/// front of an internal callfactory pool) handles backend selection on
/// its own. Used when the relay infrastructure is itself the
/// canonical session endpoint and there's no separate backend node for
/// the client to address.
///
/// Practical difference from `https-passthrough`: client-side, this
/// kind can be dialed even when the manifest declares zero backend
/// nodes — the relay does not need a backend to forward to.
const kParazitXRelayKindHttpsSession = 'https-session';

const kParazitXSupportedRelayKinds = <String>[
  kParazitXRelayKindHttpsPassthrough,
  kParazitXRelayKindHttpsSession,
];

/// Top-level manifest object.
class ParazitXManifest {
  ParazitXManifest({
    required this.version,
    required this.nodes,
    this.environment,
    List<ParazitXSignalingRelay> signalingRelays = const [],
  }) : signalingRelays = List.unmodifiable(signalingRelays);

  /// Parse a manifest from a decoded JSON map. Throws [FormatException]
  /// when required fields are missing or malformed.
  factory ParazitXManifest.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int) {
      throw const FormatException('manifest: missing or invalid "version"');
    }
    final rawNodes = json['nodes'];
    if (rawNodes is! List) {
      throw const FormatException('manifest: missing or invalid "nodes"');
    }
    final nodes = <ParazitXNode>[];
    for (var i = 0; i < rawNodes.length; i++) {
      final entry = rawNodes[i];
      if (entry is! Map) {
        throw FormatException('manifest: node[$i] is not an object');
      }
      nodes.add(ParazitXNode.fromJson(entry.cast<String, dynamic>()));
    }
    final env = json['environment'];

    final relays = <ParazitXSignalingRelay>[];
    final rawRelays = json['signaling_relays'];
    if (rawRelays != null) {
      if (rawRelays is! List) {
        throw const FormatException(
            'manifest: "signaling_relays" must be a list when present');
      }
      for (var i = 0; i < rawRelays.length; i++) {
        final entry = rawRelays[i];
        if (entry is! Map) {
          throw FormatException(
              'manifest: signaling_relays[$i] is not an object');
        }
        relays.add(
            ParazitXSignalingRelay.fromJson(entry.cast<String, dynamic>()));
      }
    }

    return ParazitXManifest(
      version: version,
      environment: env is String ? env : null,
      nodes: List.unmodifiable(nodes),
      signalingRelays: relays,
    );
  }

  /// Manifest schema version. The current client speaks version 1.
  final int version;

  /// Optional human-readable environment tag — `prod`, `prod-canary`,
  /// `staging`, etc. Used for diagnostics/logging only; does not gate
  /// node selection.
  final String? environment;

  /// All nodes from the manifest, including disabled/incompatible ones.
  /// Use [compatibleNodes] for the filtered view used by the client.
  final List<ParazitXNode> nodes;

  /// All signaling relays from the manifest, in the order the manifest
  /// declared them. Use [relaysForNode] for the filtered + sorted view
  /// the dialer actually uses.
  final List<ParazitXSignalingRelay> signalingRelays;

  /// Subset of [nodes] that the current client can actually use:
  /// enabled, on a known protocol, and exposing every required feature.
  List<ParazitXNode> get compatibleNodes => nodes
      .where(
        (n) =>
            n.enabled &&
            n.protocol == kParazitXProtocolV1 &&
            kParazitXRequiredFeatures.every(n.features.contains),
      )
      .toList(growable: false);

  /// Signaling relays usable for the given backend [nodeId].
  ///
  /// A relay applies to a node when:
  ///   * its [ParazitXSignalingRelay.appliesTo] is `null` (universal), OR
  ///   * its `appliesTo` list contains [nodeId].
  ///
  /// Relays with an unknown [ParazitXSignalingRelay.kind] are dropped so
  /// older clients ignore future relay variants instead of dialing them
  /// blind. The resulting list is sorted deterministically: highest
  /// weight first, ties broken by id ascending.
  List<ParazitXSignalingRelay> relaysForNode(String nodeId) {
    final candidates = signalingRelays.where((r) {
      if (!kParazitXSupportedRelayKinds.contains(r.kind)) return false;
      if (!_isUsableRelayUrl(r.url)) return false;
      final scope = r.appliesTo;
      if (scope == null) return true;
      return scope.contains(nodeId);
    }).toList()
      ..sort((a, b) {
        final byWeight = b.weight.compareTo(a.weight);
        if (byWeight != 0) return byWeight;
        return a.id.compareTo(b.id);
      });
    return List.unmodifiable(candidates);
  }
}

/// True iff [url] is an absolute `https://` URL with a non-empty host.
///
/// Centralised so the manifest selector can drop bad entries silently —
/// a single malformed/insecure relay URL must not poison the rest of
/// the list (or block server discovery, which is a separate concern).
bool _isUsableRelayUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return false;
  if (uri.scheme != 'https') return false;
  if (uri.host.isEmpty) return false;
  return true;
}

/// Single signaling relay listed in the manifest.
///
/// A signaling relay is an HTTPS endpoint that proxies the
/// `/v1/session` request to a backend node. It exists so the client can
/// reach the callfactory pool through infrastructure that's likely to
/// remain reachable from networks where the direct `host:port` backend
/// would be blocked (TSPU-style filtering of foreign IPs / ports).
///
/// The client treats relays as *signaling-only*: only the join-link
/// request flows through them. The actual VK call media remains
/// peer-to-peer once the join-link is in hand.
class ParazitXSignalingRelay {
  ParazitXSignalingRelay({
    required this.id,
    required this.kind,
    required this.url,
    required this.weight,
    this.appliesTo,
  });

  factory ParazitXSignalingRelay.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) {
        throw FormatException('manifest relay: missing/invalid "$key"');
      }
      return v;
    }

    int requireInt(String key) {
      final v = json[key];
      if (v is! int) {
        throw FormatException('manifest relay: missing/invalid "$key"');
      }
      return v;
    }

    List<String>? appliesTo;
    final rawApplies = json['applies_to'];
    if (rawApplies != null) {
      if (rawApplies is! List) {
        throw const FormatException(
            'manifest relay: "applies_to" must be a list when present');
      }
      appliesTo = List.unmodifiable(rawApplies.whereType<String>());
    }

    return ParazitXSignalingRelay(
      id: requireString('id'),
      kind: requireString('kind'),
      url: requireString('url'),
      weight: requireInt('weight'),
      appliesTo: appliesTo,
    );
  }

  /// Stable, human-readable id (e.g. `yc-edge-01`). Used in logs and as
  /// a deterministic tiebreaker during selection.
  final String id;

  /// Relay variant. See [kParazitXRelayKindHttpsPassthrough] and
  /// [kParazitXRelayKindHttpsSession] for the currently supported kinds;
  /// unknown kinds are filtered out by [ParazitXManifest.relaysForNode]
  /// so manifests can advertise newer kinds to newer clients without
  /// breaking older ones.
  final String kind;

  /// Absolute HTTPS URL of the relay endpoint. The path component is
  /// caller-defined — the dialer appends the relay-specific suffix
  /// (typically `/v1/session`) when issuing requests.
  final String url;

  /// Selection weight; higher = preferred.
  final int weight;

  /// Optional whitelist of node ids this relay can route to. `null`
  /// means the relay applies to every backend node.
  final List<String>? appliesTo;
}

/// Single ParazitX backend node.
class ParazitXNode {
  ParazitXNode({
    required this.id,
    required this.region,
    required this.host,
    required this.port,
    required this.protocol,
    required this.weight,
    required this.enabled,
    required this.features,
    this.sessionTtlSec,
    this.maxSessions,
  });

  factory ParazitXNode.fromJson(Map<String, dynamic> json) {
    String requireString(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) {
        throw FormatException('manifest node: missing/invalid "$key"');
      }
      return v;
    }

    int requireInt(String key) {
      final v = json[key];
      if (v is! int) {
        throw FormatException('manifest node: missing/invalid "$key"');
      }
      return v;
    }

    final rawFeatures = json['features'];
    if (rawFeatures is! List) {
      throw const FormatException('manifest node: missing/invalid "features"');
    }
    final features = rawFeatures.whereType<String>().toList(growable: false);

    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw const FormatException('manifest node: missing/invalid "enabled"');
    }

    final ttl = json['session_ttl_sec'];
    final maxSessions = json['max_sessions'];

    return ParazitXNode(
      id: requireString('id'),
      region: requireString('region'),
      host: requireString('host'),
      port: requireInt('port'),
      protocol: requireString('protocol'),
      weight: requireInt('weight'),
      enabled: enabled,
      features: List.unmodifiable(features),
      sessionTtlSec: ttl is int ? ttl : null,
      maxSessions: maxSessions is int ? maxSessions : null,
    );
  }

  /// Stable, human-readable id (e.g. `pzx-001`). Used in logs and as a
  /// deterministic tiebreaker during selection.
  final String id;

  /// ISO-style region code (`kz`, `ru`, ...). Informational for now.
  final String region;

  /// Public host or IP of the callfactory endpoint.
  final String host;

  /// callfactory TCP port (e.g. 3478).
  final int port;

  /// Protocol identifier. Only [kParazitXProtocolV1] is supported today.
  final String protocol;

  /// Selection weight; higher = preferred.
  final int weight;

  /// Whether the node is open for new sessions. Manifest can set this to
  /// `false` to drain a node without removing it from the list.
  final bool enabled;

  /// Capability flags exposed by the node.
  final List<String> features;

  /// Server-advertised session TTL in seconds. Optional; clients must not
  /// rely on a default if missing.
  final int? sessionTtlSec;

  /// Server-advertised max concurrent sessions. Optional; informational.
  final int? maxSessions;
}

/// Selects a single node from a manifest.
///
/// Today's strategy is intentionally simple and *deterministic*: highest
/// weight wins, ties broken by id ascending. Determinism keeps client
/// behaviour predictable while the canary fleet is a single node, and
/// avoids spurious churn in logs/tests.
///
/// Future iterations may layer in latency probes or sticky sessions on
/// top of this; callers should treat the result as opaque.
class ParazitXNodeSelector {
  ParazitXNodeSelector._();

  /// Returns the chosen node, or `null` when the manifest has no
  /// compatible nodes.
  static ParazitXNode? selectNode(ParazitXManifest manifest) {
    final candidates = manifest.compatibleNodes;
    if (candidates.isEmpty) return null;
    final sorted = [...candidates]..sort((a, b) {
        final byWeight = b.weight.compareTo(a.weight);
        if (byWeight != 0) return byWeight;
        return a.id.compareTo(b.id);
      });
    return sorted.first;
  }
}
