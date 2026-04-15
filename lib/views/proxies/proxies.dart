import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/views/subscription.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> with PageMixin {
  @override
  List<Widget> get actions => [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Consumer(
              builder: (context, ref, _) => TextField(
                decoration: InputDecoration(
                  hintText: appLocalizations.search,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onChanged: (value) {
                  ref.read(proxiesQueryProvider.notifier).value =
                      value.toLowerCase();
                },
              ),
            ),
          ),
        ),
      ];

  @override
  Widget? get floatingActionButton => null;

  @override
  void initState() {
    ref.listenManual(
      proxiesActionsStateProvider,
      fireImmediately: true,
      (prev, next) {
        if (prev == next) return;
        if (next.pageLabel == PageLabel.proxies) {
          initPageState();
        }
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) => const SharedProxiesBody();
}
