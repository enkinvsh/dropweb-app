import 'dart:convert';

import 'package:dropweb/services/parazitx_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParazitXManifest.fromJson', () {
    test('parses canary manifest with pzx-001 preserving fields', () {
      const raw = '''
{
  "version": 1,
  "environment": "prod-canary",
  "nodes": [
    {
      "id": "pzx-001",
      "region": "kz",
      "host": "pzx-001.meybz.asia",
      "port": 3478,
      "protocol": "parazitx-callfactory-v1",
      "weight": 100,
      "enabled": true,
      "features": ["session-v1", "socks5-local", "hysteria2-dialer"],
      "session_ttl_sec": 600,
      "max_sessions": 25
    }
  ]
}
''';

      final manifest =
          ParazitXManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(manifest.version, 1);
      expect(manifest.environment, 'prod-canary');
      expect(manifest.nodes, hasLength(1));

      final node = manifest.nodes.single;
      expect(node.id, 'pzx-001');
      expect(node.region, 'kz');
      expect(node.host, 'pzx-001.meybz.asia');
      expect(node.port, 3478);
      expect(node.protocol, 'parazitx-callfactory-v1');
      expect(node.weight, 100);
      expect(node.enabled, true);
      expect(
        node.features,
        containsAll(<String>['session-v1', 'socks5-local', 'hysteria2-dialer']),
      );
      expect(node.sessionTtlSec, 600);
      expect(node.maxSessions, 25);
    });

    test('parses minimal manifest without optional ttl/max fields', () {
      const raw = '''
{
  "version": 1,
  "nodes": [
    {
      "id": "pzx-min",
      "region": "kz",
      "host": "h",
      "port": 1,
      "protocol": "parazitx-callfactory-v1",
      "weight": 1,
      "enabled": true,
      "features": ["session-v1", "socks5-local"]
    }
  ]
}
''';

      final manifest =
          ParazitXManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(manifest.environment, isNull);
      final node = manifest.nodes.single;
      expect(node.sessionTtlSec, isNull);
      expect(node.maxSessions, isNull);
    });
  });

  group('ParazitXManifest.compatibleNodes', () {
    ParazitXNode node({
      String id = 'pzx-test',
      String protocol = 'parazitx-callfactory-v1',
      bool enabled = true,
      List<String> features = const ['session-v1', 'socks5-local'],
      int weight = 100,
    }) =>
        ParazitXNode(
          id: id,
          region: 'kz',
          host: '$id.example',
          port: 3478,
          protocol: protocol,
          weight: weight,
          enabled: enabled,
          features: features,
        );

    test('keeps enabled compatible nodes', () {
      final manifest = ParazitXManifest(version: 1, nodes: [node()]);
      expect(manifest.compatibleNodes, hasLength(1));
    });

    test('drops disabled nodes', () {
      final manifest =
          ParazitXManifest(version: 1, nodes: [node(enabled: false)]);
      expect(manifest.compatibleNodes, isEmpty);
    });

    test('drops nodes with mismatched protocol', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: [node(protocol: 'parazitx-callfactory-v2')],
      );
      expect(manifest.compatibleNodes, isEmpty);
    });

    test('drops nodes missing session-v1 feature', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: [
          node(features: const ['socks5-local']),
        ],
      );
      expect(manifest.compatibleNodes, isEmpty);
    });

    test('drops nodes missing socks5-local feature', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: [
          node(features: const ['session-v1']),
        ],
      );
      expect(manifest.compatibleNodes, isEmpty);
    });
  });

  group('ParazitXNodeSelector.selectNode', () {
    test('returns null when no compatible nodes exist', () {
      final manifest = ParazitXManifest(version: 1, nodes: const []);
      expect(ParazitXNodeSelector.selectNode(manifest), isNull);
    });

    test('returns the only compatible node when one exists', () {
      final node = ParazitXNode(
        id: 'pzx-001',
        region: 'kz',
        host: 'pzx-001.meybz.asia',
        port: 3478,
        protocol: 'parazitx-callfactory-v1',
        weight: 100,
        enabled: true,
        features: const ['session-v1', 'socks5-local'],
      );
      final manifest = ParazitXManifest(version: 1, nodes: [node]);
      expect(ParazitXNodeSelector.selectNode(manifest)?.id, 'pzx-001');
    });

    test('selects the same node deterministically across calls', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: [
          ParazitXNode(
            id: 'pzx-002',
            region: 'kz',
            host: 'pzx-002.example',
            port: 3478,
            protocol: 'parazitx-callfactory-v1',
            weight: 50,
            enabled: true,
            features: const ['session-v1', 'socks5-local'],
          ),
          ParazitXNode(
            id: 'pzx-001',
            region: 'kz',
            host: 'pzx-001.example',
            port: 3478,
            protocol: 'parazitx-callfactory-v1',
            weight: 100,
            enabled: true,
            features: const ['session-v1', 'socks5-local'],
          ),
          ParazitXNode(
            id: 'pzx-003',
            region: 'kz',
            host: 'pzx-003.example',
            port: 3478,
            protocol: 'parazitx-callfactory-v1',
            weight: 100,
            enabled: true,
            features: const ['session-v1', 'socks5-local'],
          ),
        ],
      );

      final first = ParazitXNodeSelector.selectNode(manifest);
      final second = ParazitXNodeSelector.selectNode(manifest);
      expect(first, isNotNull);
      expect(first!.id, second!.id);
      // Highest weight wins; ties broken by id ascending → pzx-001 < pzx-003
      expect(first.id, 'pzx-001');
    });

    test('skips disabled/incompatible nodes during selection', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: [
          ParazitXNode(
            id: 'pzx-disabled',
            region: 'kz',
            host: 'h',
            port: 1,
            protocol: 'parazitx-callfactory-v1',
            weight: 999,
            enabled: false,
            features: const ['session-v1', 'socks5-local'],
          ),
          ParazitXNode(
            id: 'pzx-good',
            region: 'kz',
            host: 'h',
            port: 1,
            protocol: 'parazitx-callfactory-v1',
            weight: 1,
            enabled: true,
            features: const ['session-v1', 'socks5-local'],
          ),
        ],
      );
      expect(ParazitXNodeSelector.selectNode(manifest)?.id, 'pzx-good');
    });
  });

  group('ParazitXManifest signaling_relays', () {
    test('manifest without signaling_relays parses with empty relay list', () {
      const raw = '''
{
  "version": 1,
  "nodes": [
    {
      "id": "pzx-001",
      "region": "kz",
      "host": "pzx-001.example",
      "port": 3478,
      "protocol": "parazitx-callfactory-v1",
      "weight": 100,
      "enabled": true,
      "features": ["session-v1", "socks5-local"]
    }
  ]
}
''';

      final manifest =
          ParazitXManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      expect(manifest.signalingRelays, isEmpty);
    });

    test('manifest with signaling_relays parses fields and preserves order',
        () {
      const raw = '''
{
  "version": 1,
  "nodes": [
    {
      "id": "pzx-001",
      "region": "kz",
      "host": "pzx-001.example",
      "port": 3478,
      "protocol": "parazitx-callfactory-v1",
      "weight": 100,
      "enabled": true,
      "features": ["session-v1", "socks5-local"]
    }
  ],
  "signaling_relays": [
    {
      "id": "yc-edge-01",
      "kind": "https-passthrough",
      "url": "https://yc-edge-01.example/parazitx",
      "weight": 50,
      "applies_to": ["pzx-001"]
    },
    {
      "id": "yc-edge-02",
      "kind": "https-passthrough",
      "url": "https://yc-edge-02.example/",
      "weight": 100
    }
  ]
}
''';

      final manifest =
          ParazitXManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(manifest.signalingRelays, hasLength(2));
      final r1 = manifest.signalingRelays[0];
      expect(r1.id, 'yc-edge-01');
      expect(r1.kind, 'https-passthrough');
      expect(r1.url, 'https://yc-edge-01.example/parazitx');
      expect(r1.weight, 50);
      expect(r1.appliesTo, ['pzx-001']);

      final r2 = manifest.signalingRelays[1];
      expect(r2.id, 'yc-edge-02');
      expect(r2.weight, 100);
      // missing applies_to → null → applies to all nodes
      expect(r2.appliesTo, isNull);
    });

    test('relay missing required fields throws FormatException', () {
      const raw = '''
{
  "version": 1,
  "nodes": [],
  "signaling_relays": [
    { "id": "broken", "kind": "https-passthrough" }
  ]
}
''';

      expect(
        () =>
            ParazitXManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        throwsFormatException,
      );
    });

    test('signaling_relays not a list throws FormatException', () {
      const raw = '''
{
  "version": 1,
  "nodes": [],
  "signaling_relays": "not-a-list"
}
''';

      expect(
        () =>
            ParazitXManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        throwsFormatException,
      );
    });
  });

  group('ParazitXManifest.relaysForNode', () {
    ParazitXSignalingRelay relay({
      required String id,
      int weight = 0,
      String kind = 'https-passthrough',
      List<String>? appliesTo,
    }) =>
        ParazitXSignalingRelay(
          id: id,
          kind: kind,
          url: 'https://$id.example/',
          weight: weight,
          appliesTo: appliesTo,
        );

    test('returns empty when no relays configured', () {
      final manifest = ParazitXManifest(version: 1, nodes: const []);
      expect(manifest.relaysForNode('pzx-001'), isEmpty);
    });

    test('returns universal relays (no applies_to) for any node', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [relay(id: 'r1')],
      );
      expect(manifest.relaysForNode('pzx-anything').map((r) => r.id), ['r1']);
    });

    test('respects applies_to whitelist', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          relay(id: 'only-001', appliesTo: ['pzx-001']),
          relay(id: 'only-002', appliesTo: ['pzx-002']),
          relay(id: 'universal'),
        ],
      );
      final forA = manifest.relaysForNode('pzx-001').map((r) => r.id).toList();
      expect(forA, containsAll(<String>['only-001', 'universal']));
      expect(forA, isNot(contains('only-002')));
    });

    test('sorts by weight desc then id asc', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          relay(id: 'b', weight: 50),
          relay(id: 'a', weight: 100),
          relay(id: 'c', weight: 100),
        ],
      );
      // weight 100 first (a < c), then weight 50 (b)
      expect(manifest.relaysForNode('any').map((r) => r.id).toList(),
          ['a', 'c', 'b']);
    });

    test('drops relays with unknown kind', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          relay(id: 'good'),
          relay(id: 'bad', kind: 'tcp-tunnel'),
        ],
      );
      expect(manifest.relaysForNode('any').map((r) => r.id).toList(), ['good']);
    });

    test('keeps relays of kind https-session alongside https-passthrough', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          relay(
            id: 'session-relay',
            kind: kParazitXRelayKindHttpsSession,
            weight: 100,
          ),
          relay(
            id: 'passthrough-relay',
            kind: kParazitXRelayKindHttpsPassthrough,
            weight: 50,
          ),
          relay(id: 'unknown-kind', kind: 'tcp-tunnel', weight: 200),
        ],
      );
      final result = manifest.relaysForNode('any');
      expect(result.map((r) => r.id).toList(),
          ['session-relay', 'passthrough-relay']);
      expect(result.map((r) => r.kind).toList(),
          [kParazitXRelayKindHttpsSession, kParazitXRelayKindHttpsPassthrough]);
    });

    test('drops non-HTTPS https-session relay URLs', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          ParazitXSignalingRelay(
            id: 'http-session',
            kind: kParazitXRelayKindHttpsSession,
            url: 'http://insecure.example/v1/session',
            weight: 100,
          ),
          ParazitXSignalingRelay(
            id: 'good-session',
            kind: kParazitXRelayKindHttpsSession,
            url: 'https://yc.example.net',
            weight: 1,
          ),
        ],
      );
      expect(
        manifest.relaysForNode('any').map((r) => r.id).toList(),
        ['good-session'],
      );
    });

    test('drops non-HTTPS relay URLs', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          ParazitXSignalingRelay(
            id: 'plain-http',
            kind: 'https-passthrough',
            url: 'http://insecure.example/parazitx',
            weight: 100,
          ),
          ParazitXSignalingRelay(
            id: 'wss',
            kind: 'https-passthrough',
            url: 'wss://insecure.example/',
            weight: 100,
          ),
          ParazitXSignalingRelay(
            id: 'ok',
            kind: 'https-passthrough',
            url: 'https://secure.example/',
            weight: 1,
          ),
        ],
      );
      expect(
        manifest.relaysForNode('any').map((r) => r.id).toList(),
        ['ok'],
      );
    });

    test('drops malformed or hostless relay URLs', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          ParazitXSignalingRelay(
            id: 'not-a-url',
            kind: 'https-passthrough',
            url: 'not-a-url',
            weight: 100,
          ),
          ParazitXSignalingRelay(
            id: 'no-host',
            kind: 'https-passthrough',
            url: 'https:///path',
            weight: 100,
          ),
          ParazitXSignalingRelay(
            id: 'empty',
            kind: 'https-passthrough',
            url: '   ',
            weight: 100,
          ),
          ParazitXSignalingRelay(
            id: 'good',
            kind: 'https-passthrough',
            url: 'https://relay.example/',
            weight: 1,
          ),
        ],
      );
      expect(
        manifest.relaysForNode('any').map((r) => r.id).toList(),
        ['good'],
      );
    });

    test('keeps valid https relays through filter', () {
      final manifest = ParazitXManifest(
        version: 1,
        nodes: const [],
        signalingRelays: [
          ParazitXSignalingRelay(
            id: 'a',
            kind: 'https-passthrough',
            url: 'https://a.example/parazitx',
            weight: 50,
          ),
          ParazitXSignalingRelay(
            id: 'b',
            kind: 'https-passthrough',
            url: 'https://b.example:8443/',
            weight: 100,
          ),
        ],
      );
      expect(
        manifest.relaysForNode('any').map((r) => r.id).toList(),
        ['b', 'a'],
      );
    });
  });
}
