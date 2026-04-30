import 'package:flutter/material.dart';

/// User-facing VK Calls states. Internal tunnel phases collapse into these.
///
/// Strictly named in product terms — "stability mode" — never in
/// VPN/proxy/relay vocabulary. The visible UI must read like a banking
/// app diagnostic, not a network engineer's console.
///
/// Phase 2 widens the bucket set so the hero card can communicate the
/// actual activation phase to the user instead of one generic
/// "connecting" blob:
///
/// - [idle]         — disconnected, ready to start.
/// - [syncing]      — fetching configuration / refreshing profile.
/// - [verification] — VK is asking for a captcha / access check.
/// - [connecting]   — building the local VPN channel.
/// - [protected]    — stability mode is active.
/// - [error]        — last attempt failed; surface a sanitised reason.
enum VkCallsState {
  idle,
  syncing,
  verification,
  connecting,
  protected,
  error,
}

extension VkCallsStateAccent on VkCallsState {
  /// Single accent color per state. Reuses theme tokens — no new
  /// constants. VK blue maps to `colorScheme.primary` in our theme.
  Color accentColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (this) {
      case VkCallsState.idle:
        return cs.outline;
      case VkCallsState.syncing:
        return cs.tertiary;
      case VkCallsState.verification:
        return cs.secondary;
      case VkCallsState.connecting:
        return cs.tertiary;
      case VkCallsState.protected:
        return cs.primary;
      case VkCallsState.error:
        return cs.error;
    }
  }
}
