import 'dart:async';
import 'dart:developer' as developer;

import 'package:dropweb/enum/enum.dart' show PageLabel;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/plugins/vk_tunnel_plugin.dart';
import 'package:dropweb/services/log_buffer.dart';
import 'package:dropweb/services/parazitx_manager.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ParazitXPage extends StatefulWidget {
  const ParazitXPage({super.key});

  @override
  State<ParazitXPage> createState() => _ParazitXPageState();
}

/// User-visible representation of an internal tunnel status string.
///
/// Maps the 6+ raw phases emitted by librelay to 4 user-facing states
/// modelled after NordVPN/ExpressVPN: idle, working, protected, error.
@immutable
class _StatusView {
  const _StatusView({
    required this.text,
    required this.color,
    required this.showProgress,
  });

  final String text;
  final Color color;
  final bool showProgress;
}

_StatusView _mapStatus(String status) {
  if (TunnelStatus.isFailure(status)) {
    final msg = status.startsWith('ERROR:')
        ? status.substring('ERROR:'.length).trim()
        : 'Ошибка подключения';
    return _StatusView(
      text: msg.isEmpty ? 'Ошибка подключения' : msg,
      color: Colors.red,
      showProgress: false,
    );
  }
  if (TunnelStatus.isTunnelReady(status)) {
    return const _StatusView(
      text: 'Защищено',
      color: Colors.green,
      showProgress: false,
    );
  }
  if (status.startsWith('CAPTCHA:') ||
      status.toLowerCase().contains('captcha')) {
    return const _StatusView(
      text: 'Проверка...',
      color: Colors.amber,
      showProgress: true,
    );
  }
  if (status.isEmpty ||
      status == TunnelStatus.ready ||
      status == 'disconnected') {
    return const _StatusView(
      text: 'Нажмите для подключения',
      color: Colors.grey,
      showProgress: false,
    );
  }
  // Default: any other progress phase ("Getting ...", "CONNECTING",
  // "Auth complete", "Fetching config...", etc.) — connecting bucket.
  return const _StatusView(
    text: 'Подключение...',
    color: Colors.amber,
    showProgress: true,
  );
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
    if (ParazitXManager.isTunnelReady) {
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
    final l = AppLocalizations.of(context);
    final view = _mapStatus(_rawStatus);
    return Scaffold(
      appBar: AppBar(title: Text(l.parazitx)),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConnectionStatusBanner(view: view),
                const ListHeader(title: 'VK Звонки'),
                const ParazitXSectionItem(),
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

/// NordVPN-style status banner: animated text crossfade + optional
/// indeterminate progress bar.
///
/// The banner is the only place the user sees "what is happening" while
/// the tunnel comes up. Internal phases ("Getting anonymous token...",
/// "Auth complete", etc.) are collapsed into 4 user-facing buckets by
/// [_mapStatus]. This is the same pattern NordVPN/ExpressVPN use:
/// idle / connecting / connected / error — never expose protocol jargon.
class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner({required this.view});

  final _StatusView view;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: view.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: view.color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    view.text,
                    key: ValueKey<String>('parazitx-status-text:${view.text}'),
                    style: TextStyle(
                      color: view.color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: view.showProgress
                ? LinearProgressIndicator(
                    key: const ValueKey<String>('parazitx-status-progress'),
                    minHeight: 2,
                    color: view.color,
                    backgroundColor: view.color.withValues(alpha: 0.15),
                  )
                : const SizedBox(
                    key: ValueKey<String>('parazitx-status-no-progress'),
                    height: 2,
                  ),
          ),
        ],
      ),
    );
  }
}
