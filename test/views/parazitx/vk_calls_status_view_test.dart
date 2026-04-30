import 'package:dropweb/views/parazitx/vk_calls_state.dart';
import 'package:dropweb/views/parazitx/vk_calls_status_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mapTunnelStatusToView', () {
    test('empty / READY / disconnected → idle', () {
      for (final s in <String>['', 'READY', 'disconnected']) {
        final v = mapTunnelStatusToView(s);
        expect(v.state, VkCallsState.idle, reason: 'for "$s"');
        expect(v.headline, 'Готово');
        expect(v.detail, 'Включите режим для VK Звонков.');
        expect(v.detailsLines, isEmpty);
      }
    });

    test('Fetching config... → syncing', () {
      final v = mapTunnelStatusToView('Fetching config...');
      expect(v.state, VkCallsState.syncing);
      expect(v.headline, 'Синхронизация');
      expect(v.detail, 'Обновляем параметры.');
    });

    test('strings containing profile/subscription/config → syncing', () {
      for (final s in <String>[
        'Loading profile',
        'Refreshing Subscription',
        'updating CONFIG now',
      ]) {
        final v = mapTunnelStatusToView(s);
        expect(v.state, VkCallsState.syncing, reason: 'for "$s"');
        expect(v.headline, 'Синхронизация');
      }
    });

    test('CAPTCHA:url → verification (Проверка VK)', () {
      final v = mapTunnelStatusToView('CAPTCHA:http://127.0.0.1:5000/');
      expect(v.state, VkCallsState.verification);
      expect(v.headline, 'Проверка VK');
      expect(v.detail, 'Подтверждаем доступ.');
    });

    test('strings containing captcha (case insensitive) → verification', () {
      final v = mapTunnelStatusToView('Solving Captcha challenge');
      expect(v.state, VkCallsState.verification);
      expect(v.headline, 'Проверка VK');
    });

    test('CONNECTING → connecting', () {
      final v = mapTunnelStatusToView('CONNECTING');
      expect(v.state, VkCallsState.connecting);
      expect(v.headline, 'Подключаем');
      expect(v.detail, 'Обычно до 15 секунд.');
    });

    test('unknown progress string → connecting fallback', () {
      final v = mapTunnelStatusToView('SOME_FUTURE_PROGRESS_STATE');
      expect(v.state, VkCallsState.connecting);
      expect(v.headline, 'Подключаем');
    });

    test('TUNNEL_CONNECTED → protected with details lines', () {
      final v = mapTunnelStatusToView('TUNNEL_CONNECTED');
      expect(v.state, VkCallsState.protected);
      expect(v.headline, 'Активно');
      expect(v.detail, 'VK Звонки в режиме стабильности.');
      expect(v.detailsLines, <String>[
        'Локальный канал: активен',
        'Резервный маршрут: готов',
      ]);
    });

    test('TUNNEL_ACTIVE → protected', () {
      final v = mapTunnelStatusToView('TUNNEL_ACTIVE');
      expect(v.state, VkCallsState.protected);
      expect(v.headline, 'Активно');
    });

    test('TUNNEL_LOST → error', () {
      final v = mapTunnelStatusToView('TUNNEL_LOST');
      expect(v.state, VkCallsState.error);
      expect(v.headline, 'Не удалось включить режим');
    });

    test('CALL_FAILED → error', () {
      final v = mapTunnelStatusToView('CALL_FAILED');
      expect(v.state, VkCallsState.error);
    });

    test('ERROR: with safe message keeps the message', () {
      final v = mapTunnelStatusToView('ERROR: VK сессия истекла');
      expect(v.state, VkCallsState.error);
      expect(v.detail, 'VK сессия истекла');
    });

    test('ERROR: with internal token sanitises to generic copy', () {
      final v = mapTunnelStatusToView('ERROR: relay manifest fetch failed');
      expect(v.state, VkCallsState.error);
      expect(v.detail, 'Не удалось подключить режим стабильности.');
    });

    test('ERROR: empty falls back to generic retry copy', () {
      final v = mapTunnelStatusToView('ERROR:');
      expect(v.state, VkCallsState.error);
      expect(v.detail, 'Попробуйте ещё раз через минуту.');
    });
  });
}
