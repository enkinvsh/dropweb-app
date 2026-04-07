import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/clash_config.dart';
import 'package:dropweb/providers/config.dart' show patchClashConfigProvider;
import 'package:dropweb/state.dart';
import 'package:dropweb/views/config/dns.dart';
import 'package:dropweb/views/config/general.dart';
import 'package:dropweb/views/config/network.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class ConfigView extends StatefulWidget {
  const ConfigView({super.key});

  @override
  State<ConfigView> createState() => _ConfigViewState();
}

class _ConfigViewState extends State<ConfigView> {
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      ListItem.open(
        title: Text(appLocalizations.general),
        subtitle: Text(appLocalizations.generalDesc),
        leading: HugeIcon(icon: HugeIcons.strokeRoundedLegalHammer, size: 24),
        delegate: OpenDelegate(
          title: appLocalizations.general,
          widget: generateListView(
            generalItems,
          ),
          blur: false,
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.network),
        subtitle: Text(appLocalizations.networkDesc),
        leading: HugeIcon(icon: HugeIcons.strokeRoundedKey01, size: 24),
        delegate: OpenDelegate(
          title: appLocalizations.network,
          blur: false,
          widget: const NetworkListView(),
        ),
      ),
      ListItem.open(
        title: const Text("DNS"),
        subtitle: Text(appLocalizations.dnsDesc),
        leading: HugeIcon(icon: HugeIcons.strokeRoundedServerStack01, size: 24),
        delegate: OpenDelegate(
          title: "DNS",
          action: Consumer(
              builder: (_, ref, __) => IconButton(
                    onPressed: () async {
                      final res = await globalState.showMessage(
                        title: appLocalizations.reset,
                        message: TextSpan(
                          text: appLocalizations.resetTip,
                        ),
                      );
                      if (res != true) {
                        return;
                      }
                      ref.read(patchClashConfigProvider.notifier).updateState(
                            (state) => state.copyWith(
                              dns: defaultDns,
                            ),
                          );
                    },
                    tooltip: appLocalizations.reset,
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowReloadHorizontal,
                        size: 24),
                  )),
          widget: const DnsListView(),
          blur: false,
        ),
      )
    ];
    return generateListView(
      items
          .separated(
            const Divider(
              height: 0,
            ),
          )
          .toList(),
    );
  }
}
