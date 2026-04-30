import 'dart:async';
import 'dart:developer' as developer;

import 'package:dropweb/enum/enum.dart' show PageLabel;
import 'package:dropweb/plugins/vk_tunnel_plugin.dart';
import 'package:dropweb/services/log_buffer.dart';
import 'package:dropweb/services/parazitx_manager.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/views/parazitx/footer_diagnostics.dart';
import 'package:dropweb/views/parazitx/hero_state_card.dart';
import 'package:dropweb/views/parazitx/vk_calls_state.dart';
import 'package:dropweb/views/parazitx/vk_calls_status_view.dart';
import 'package:flutter/material.dart';

class ParazitXPage extends StatefulWidget {
  const ParazitXPage({super.key});

  @override
  State<ParazitXPage> createState() => _ParazitXPageState();
}

class _ParazitXPageState extends State<ParazitXPage> {
  // Overlay safety budget. ParazitXVpnService needs ~1-2s after
  // TUNNEL_CONNECTED to call establish(); we want the overlay to outlive
  // that bring-up but never linger if the navigation/lifecycle pipeline
  // misfires. 6s is a generous, never-noticed-by-user upper bound.
  static const Duration _handoffSafetyBudget = Duration(seconds: 6);
  static const Duration _handoffNavigationDelay = Duration(seconds: 2);

  StreamSubscription<String>? _statusSub;
  Timer? _handoffSafetyTimer;
  bool _handoffStarted = false;
  bool _tunnelReached = false;
  bool _showHandoff = false;
  String _rawStatus = '';

  @override
  void initState() {
    super.initState();
    // Seed from the manager's authoritative active flag so the hero card
    // doesn't briefly render "Подключаем" / idle copy when the page is
    // rebuilt while the tunnel is already up. `isTunnelReady` is the
    // strongest signal, but `isActive` (no failure) is also enough to
    // render the protected view via the build-time override below.
    if (ParazitXManager.isTunnelReady || ParazitXManager.isActive) {
      _rawStatus = TunnelStatus.tunnelConnected;
    }
    _statusSub = VkTunnelPlugin.statusStream.listen(_onStatus);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _handoffSafetyTimer?.cancel();
    super.dispose();
  }

  void _log(String msg) {
    final tagged = '[ParazitX][handoff] $msg';
    developer.log(tagged, name: 'ParazitX');
    LogBuffer.instance.add(tagged);
  }

  void _onStatus(String status) {
    if (!mounted) return;

    setState(() => _rawStatus = status);
    _log('status received: $status');

    // Captcha re-appears: pretend handoff never started, hide overlay.
    if (TunnelStatus.captchaUrl(status) != null) {
      if (_handoffStarted || _showHandoff) {
        _log('captcha url received — resetting handoff state');
        _hideHandoffOverlay();
        _handoffStarted = false;
        _tunnelReached = false;
      }
      return;
    }

    if (!_handoffStarted) {
      final captureNow = status.startsWith('Captcha solved') ||
          TunnelStatus.isTunnelReady(status);
      if (captureNow) {
        _handoffStarted = true;
        _showHandoffOverlay();
      }
    }

    if (TunnelStatus.isTunnelReady(status) && !_tunnelReached) {
      _tunnelReached = true;
      unawaited(_scheduleHandoff());
    }
  }

  void _showHandoffOverlay() {
    if (!mounted) return;
    if (_showHandoff) return;
    _log('overlay show');
    setState(() => _showHandoff = true);

    // Safety net: the overlay MUST disappear after the safety budget
    // even if _scheduleHandoff() never runs (e.g. the page got popped
    // by something else, or a status race nukes mounted before we get
    // there). Inline overlay = Stack child = it cannot orphan into the
    // root Navigator, but we still want a visible blackscreen-killer.
    _handoffSafetyTimer?.cancel();
    _handoffSafetyTimer = Timer(_handoffSafetyBudget, () {
      if (!mounted) return;
      if (!_showHandoff) return;
      _log('safety timeout fired — forcing overlay hide');
      _hideHandoffOverlay();
    });
  }

  void _hideHandoffOverlay() {
    _handoffSafetyTimer?.cancel();
    _handoffSafetyTimer = null;
    if (!mounted) return;
    if (!_showHandoff) return;
    _log('overlay hide');
    setState(() => _showHandoff = false);
  }

  Future<void> _scheduleHandoff() async {
    // ParazitXVpnService needs ~1-2s after TUNNEL_CONNECTED to call
    // establish() and let Android apply the network handoff. Wait it out
    // before unmounting and switching the tab.
    _log('scheduleHandoff: waiting ${_handoffNavigationDelay.inSeconds}s');
    await Future<void>.delayed(_handoffNavigationDelay);
    if (!mounted) {
      _log('scheduleHandoff: not mounted after delay, aborting');
      return;
    }

    // Hide the inline overlay BEFORE touching navigation. If something
    // throws during navigation we still leave the page in a clean state.
    _hideHandoffOverlay();

    _log('navigation start: popUntil(isFirst) + toPage(dashboard)');
    Navigator.of(context).popUntil((route) => route.isFirst);
    globalState.appController.toPage(PageLabel.dashboard);
    _log('navigation done');
  }

  @override
  Widget build(BuildContext context) {
    // Source of truth for the hero card: prefer `ParazitXManager.isActive`
    // over the raw status. After a hot restart (or any time the page
    // remounts before the next TUNNEL_CONNECTED arrives), `_rawStatus`
    // can be empty or stale `CONNECTING`, which maps to idle/connecting
    // copy — yet the manager already considers the mode active. Showing
    // "Подключаем" while the CTA reflects the steady state ("Включить
    // режим" / "Сессия VK подключена.") is the visible mismatch users
    // see. When the manager says active and the latest status is not a
    // failure, render the protected view directly.
    var view = mapTunnelStatusToView(_rawStatus);
    if (ParazitXManager.isActive &&
        !TunnelStatus.isFailure(_rawStatus) &&
        view.state != VkCallsState.protected) {
      view = mapTunnelStatusToView(TunnelStatus.tunnelConnected);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('VK Звонки')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroStateCard(
                  state: view.state,
                  headline: view.headline,
                  detail: view.detail,
                ),
                // Activation logic stays inside ParazitXSectionItem —
                // VK login, captcha listener, mihomo-stop dialog,
                // optimistic toggle, error snackbars, deactivate. The
                // standalone page renders the primary-CTA layout: one
                // full-width button, no settings switch row.
                const ParazitXSectionItem(
                  layout: ParazitXSectionLayout.primaryCta,
                ),
                const FooterDiagnostics(
                  line: 'Локальный VPN-канал для VK Звонков.',
                ),
              ],
            ),
          ),
          _buildHandoffOverlay(context),
        ],
      ),
    );
  }

  /// Inline handoff overlay. Lives inside [ParazitXPage]'s Stack so it is
  /// torn down with the page — it cannot orphan into the root Navigator
  /// (the bug that produced the post-connect blackscreen on Pixel 10).
  Widget _buildHandoffOverlay(BuildContext context) {
    // While visible the overlay must swallow taps so the user can't
    // re-trigger ParazitXSectionItem mid-handoff. AbsorbPointer is
    // sufficient for that — no PopScope here. PopScope only behaves
    // correctly as a route entry, and nesting it inside a Stack child
    // either no-ops or hijacks back-press for the whole route. Pop
    // handling, if ever needed, belongs at the page level.
    return AbsorbPointer(
      key: const ValueKey<String>('parazitx-handoff-overlay'),
      absorbing: _showHandoff,
      child: IgnorePointer(
        ignoring: !_showHandoff,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          opacity: _showHandoff ? 1 : 0,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.78),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Защищено. Переключение...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
