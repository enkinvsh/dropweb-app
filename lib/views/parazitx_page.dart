import 'dart:async';

import 'package:dropweb/enum/enum.dart' show PageLabel;
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/plugins/vk_tunnel_plugin.dart';
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
  StreamSubscription<String>? _statusSub;
  bool _handoffStarted = false;
  bool _tunnelReached = false;
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
    super.dispose();
  }

  void _onStatus(String status) {
    if (!mounted) return;

    setState(() => _rawStatus = status);

    if (TunnelStatus.captchaUrl(status) != null) {
      if (_handoffStarted) {
        Navigator.of(context, rootNavigator: true).pop();
        _handoffStarted = false;
      }
      return;
    }

    if (!_handoffStarted) {
      final captureNow = status.startsWith('Captcha solved') ||
          TunnelStatus.isTunnelReady(status);
      if (captureNow) {
        _handoffStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showHandoffModal();
        });
      }
    }

    if (TunnelStatus.isTunnelReady(status) && !_tunnelReached) {
      _tunnelReached = true;
      _scheduleHandoff();
    }
  }

  void _showHandoffModal() {
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    ));
  }

  Future<void> _scheduleHandoff() async {
    // ParazitXVpnService needs ~1-2s after TUNNEL_CONNECTED to call
    // establish() and let Android apply the network handoff. Wait it out
    // before unmounting and switching the tab.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    Navigator.of(context).popUntil((route) => route.isFirst);
    globalState.appController.toPage(PageLabel.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final view = _mapStatus(_rawStatus);
    return Scaffold(
      appBar: AppBar(title: Text(l.parazitx)),
      body: SingleChildScrollView(
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
                    key: ValueKey<String>(view.text),
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
                    key: const ValueKey<String>('progress'),
                    minHeight: 2,
                    color: view.color,
                    backgroundColor: view.color.withValues(alpha: 0.15),
                  )
                : const SizedBox(
                    key: ValueKey<String>('no-progress'),
                    height: 2,
                  ),
          ),
        ],
      ),
    );
  }
}
