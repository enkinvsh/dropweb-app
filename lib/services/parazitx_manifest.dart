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

/// Top-level manifest object.
class ParazitXManifest {
  ParazitXManifest({
    required this.version,
    required this.nodes,
    this.environment,
  });

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
    return ParazitXManifest(
      version: version,
      environment: env is String ? env : null,
      nodes: List.unmodifiable(nodes),
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
