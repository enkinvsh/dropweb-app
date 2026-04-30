import 'package:dropweb/services/mihomo_dialer_proxy_patcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseConfig() => <String, dynamic>{
        'proxies': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'hy2-tokyo',
            'type': 'hysteria2',
            'server': 'hy2.example.com',
            'port': 443,
            'password': 'secret',
          },
          <String, dynamic>{
            'name': 'hy1-osaka',
            'type': 'hysteria',
            'server': 'hy1.example.com',
            'port': 443,
            'auth_str': 'secret',
          },
          <String, dynamic>{
            'name': 'vmess-frankfurt',
            'type': 'vmess',
            'server': 'vm.example.com',
            'port': 443,
          },
        ],
        'proxy-groups': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'PROXY',
            'type': 'select',
            'proxies': <String>['hy2-tokyo', 'hy1-osaka', 'vmess-frankfurt'],
          },
        ],
        'rules': <String>['MATCH,PROXY'],
        'rule-providers': <String, dynamic>{
          'geoip-cn': <String, dynamic>{'type': 'http'},
        },
        'dns': <String, dynamic>{'enable': true},
        'tun': <String, dynamic>{'enable': true},
      };

  group('MihomoDialerProxyPatcher.patch', () {
    test('adds bridge proxy with correct fields', () {
      final config = baseConfig();
      final result = MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);

      expect(result.bridgeAdded, true);
      expect(result.bridgeUpdated, false);

      final proxies = config['proxies'] as List;
      final bridge = proxies
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == '__dropweb_parazitx_vk_bridge');
      expect(bridge['type'], 'socks5');
      expect(bridge['server'], '127.0.0.1');
      expect(bridge['port'], 1080);
    });

    test('adds dialer-proxy to hysteria and hysteria2 entries only', () {
      final config = baseConfig();
      final result = MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);

      expect(result.patchedCount, 2);
      final proxies = (config['proxies'] as List).cast<Map<String, dynamic>>();
      final hy2 = proxies.firstWhere((p) => p['name'] == 'hy2-tokyo');
      final hy1 = proxies.firstWhere((p) => p['name'] == 'hy1-osaka');
      final vmess = proxies.firstWhere((p) => p['name'] == 'vmess-frankfurt');

      expect(hy2['dialer-proxy'], '__dropweb_parazitx_vk_bridge');
      expect(hy1['dialer-proxy'], '__dropweb_parazitx_vk_bridge');
      expect(vmess.containsKey('dialer-proxy'), false);
    });

    test('does not modify proxy-groups, rules, rule-providers, dns, tun', () {
      final config = baseConfig();
      final originalGroups = List<Map<String, dynamic>>.from(
        (config['proxy-groups'] as List).cast<Map<String, dynamic>>(),
      );
      final originalRules = List<String>.from(config['rules'] as List);
      final originalRuleProviders =
          Map<String, dynamic>.from(config['rule-providers'] as Map);
      final originalDns = Map<String, dynamic>.from(config['dns'] as Map);
      final originalTun = Map<String, dynamic>.from(config['tun'] as Map);

      MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);

      expect(config['proxy-groups'], originalGroups);
      expect(config['rules'], originalRules);
      expect(config['rule-providers'], originalRuleProviders);
      expect(config['dns'], originalDns);
      expect(config['tun'], originalTun);
    });

    test('is idempotent: second patch updates port and does not duplicate', () {
      final config = baseConfig();
      MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);
      final result2 = MihomoDialerProxyPatcher.patch(config, bridgePort: 1090);

      final proxies = (config['proxies'] as List).cast<Map<String, dynamic>>();
      final bridges = proxies
          .where((p) => p['name'] == '__dropweb_parazitx_vk_bridge')
          .toList();
      expect(bridges, hasLength(1));
      expect(bridges.single['port'], 1090);

      expect(result2.bridgeAdded, false);
      expect(result2.bridgeUpdated, true);
    });

    test('skips hysteria proxy with existing non-Dropweb dialer-proxy', () {
      final config = baseConfig();
      final proxies = (config['proxies'] as List).cast<Map<String, dynamic>>();
      proxies.firstWhere((p) => p['name'] == 'hy2-tokyo')['dialer-proxy'] =
          'user-bridge';

      final result = MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);

      final hy2 = proxies.firstWhere((p) => p['name'] == 'hy2-tokyo');
      expect(hy2['dialer-proxy'], 'user-bridge');
      expect(result.skipped, hasLength(1));
      expect(result.skipped.single.name, 'hy2-tokyo');
      expect(result.patchedCount, 1); // hy1-osaka still patched
      expect(result.skippedCount, 1);
    });

    test('overwrites existing Dropweb-owned dialer-proxy on re-patch', () {
      final config = baseConfig();
      // First patch sets dialer-proxy = bridge name on hy2-tokyo / hy1-osaka.
      MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);
      // Second patch must NOT treat our own marker as user override.
      final result2 = MihomoDialerProxyPatcher.patch(config, bridgePort: 1090);
      expect(result2.skippedCount, 0);
    });

    test('handles config without proxies field gracefully', () {
      final config = <String, dynamic>{};
      final result = MihomoDialerProxyPatcher.patch(config, bridgePort: 1080);

      expect(config.containsKey('proxies'), true);
      final proxies = (config['proxies'] as List).cast<Map<String, dynamic>>();
      expect(proxies, hasLength(1));
      expect(proxies.single['name'], '__dropweb_parazitx_vk_bridge');
      expect(result.bridgeAdded, true);
      expect(result.patchedCount, 0);
    });

    test('uses custom bridge server when provided', () {
      final config = <String, dynamic>{};
      MihomoDialerProxyPatcher.patch(
        config,
        bridgePort: 1080,
        bridgeServer: '127.0.0.2',
      );
      final proxies = (config['proxies'] as List).cast<Map<String, dynamic>>();
      expect(proxies.single['server'], '127.0.0.2');
    });
  });
}
