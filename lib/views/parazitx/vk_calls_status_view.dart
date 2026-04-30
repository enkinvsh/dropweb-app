import 'package:dropweb/plugins/vk_tunnel_plugin.dart';

import 'vk_calls_state.dart';

/// View-model for one VK Calls status snapshot.
///
/// Maps the raw librelay status string to a user-facing [VkCallsState]
/// plus the human-readable copy that the hero card and connection-details
/// panel render. The visible vocabulary must stay product-grade —
/// "режим стабильности", "локальный VPN-канал" — never expose internal
/// wording such as parazit/relay/manifest/tunnel/proxy/librelay/mihomo/
/// signaling/subscription/profile.
class VkCallsStatusView {
  const VkCallsStatusView({
    required this.state,
    required this.headline,
    required this.detail,
    required this.detailsLines,
  });

  final VkCallsState state;
  final String headline;
  final String? detail;
  final List<String> detailsLines;
}

/// Pure mapping from raw [TunnelStatus] strings to [VkCallsStatusView].
///
/// Six explicit phases drive the hero card so the user sees what is
/// happening (idle, syncing, verification, connecting, protected, error)
/// instead of a generic "connecting" blob. Native code keeps emitting
/// the existing `STATUS:` strings — this is a Dart-only widening.
///
/// Visible copy is intentionally short to avoid widow words on the
/// 360-dp Pixel layout.
VkCallsStatusView mapTunnelStatusToView(String status) {
  if (TunnelStatus.isFailure(status)) {
    final raw = status.startsWith('ERROR:')
        ? status.substring('ERROR:'.length).trim()
        : '';
    final sanitised = sanitiseVkCallsErrorMessage(raw);
    return VkCallsStatusView(
      state: VkCallsState.error,
      headline: 'Не удалось включить режим',
      detail:
          sanitised.isEmpty ? 'Попробуйте ещё раз через минуту.' : sanitised,
      detailsLines: const <String>[],
    );
  }
  if (TunnelStatus.isTunnelReady(status)) {
    return const VkCallsStatusView(
      state: VkCallsState.protected,
      headline: 'Активно',
      detail: 'VK Звонки в режиме стабильности.',
      detailsLines: <String>[
        'Локальный канал: активен',
        'Резервный маршрут: готов',
      ],
    );
  }
  if (status.startsWith('CAPTCHA:') ||
      status.toLowerCase().contains('captcha')) {
    return const VkCallsStatusView(
      state: VkCallsState.verification,
      headline: 'Проверка VK',
      detail: 'Подтверждаем доступ.',
      detailsLines: <String>[],
    );
  }
  if (status.isEmpty ||
      status == TunnelStatus.ready ||
      status == 'disconnected') {
    return const VkCallsStatusView(
      state: VkCallsState.idle,
      headline: 'Готово',
      detail: 'Включите режим для VK Звонков.',
      detailsLines: <String>[],
    );
  }
  // Sync-ish statuses: librelay emits "Fetching config..." while pulling
  // the VK profile / subscription manifest. We treat any progress string
  // mentioning config / profile / subscription as "syncing".
  final lower = status.toLowerCase();
  if (status == TunnelStatus.fetchingConfig ||
      lower.contains('fetching config') ||
      lower.contains('config') ||
      lower.contains('profile') ||
      lower.contains('subscription')) {
    return const VkCallsStatusView(
      state: VkCallsState.syncing,
      headline: 'Синхронизация',
      detail: 'Обновляем параметры.',
      detailsLines: <String>[],
    );
  }
  return const VkCallsStatusView(
    state: VkCallsState.connecting,
    headline: 'Подключаем',
    detail: 'Обычно до 15 секунд.',
    detailsLines: <String>[],
  );
}

/// Strip transport-layer jargon out of server error strings before
/// surfacing them to the user. Anything carrying internal vocabulary
/// collapses into a generic message — the user does not need to know
/// the difference between a relay, a manifest, or a tunnel hop.
String sanitiseVkCallsErrorMessage(String raw) {
  if (raw.isEmpty) return '';
  final lower = raw.toLowerCase();
  const internalTokens = <String>[
    'parazit',
    'relay',
    'manifest',
    'tunnel',
    'proxy',
    'librelay',
    'mihomo',
    'signaling',
    'subscription',
    'profile',
  ];
  for (final t in internalTokens) {
    if (lower.contains(t)) {
      return 'Не удалось подключить режим стабильности.';
    }
  }
  return raw;
}
