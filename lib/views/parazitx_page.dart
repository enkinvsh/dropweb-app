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

class _ParazitXPageState extends State<ParazitXPage> {
  StreamSubscription<String>? _statusSub;
  bool _handoffStarted = false;
  bool _tunnelReached = false;

  @override
  void initState() {
    super.initState();
    _statusSub = VkTunnelPlugin.statusStream.listen(_onStatus);
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  void _onStatus(String status) {
    if (!mounted) return;

    if (!_handoffStarted) {
      final captureNow = status.startsWith('Captcha solved') ||
          status == TunnelStatus.connecting ||
          TunnelStatus.isTunnelReady(status);
      if (captureNow) {
        _handoffStarted = true;
        // Show on the next frame so the CaptchaScreen has time to actually
        // pop. Both the captcha and us listen to "Captcha solved" — if we
        // call showDialog in the same microtask, our dialog races with
        // captcha's Navigator.pop and ends up dismissed alongside it.
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
    return Scaffold(
      appBar: AppBar(title: Text(l.parazitx)),
      body: const SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListHeader(title: 'VK Звонки'),
            ParazitXSectionItem(),
          ],
        ),
      ),
    );
  }
}
