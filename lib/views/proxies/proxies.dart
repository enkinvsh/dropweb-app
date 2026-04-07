import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/proxies/list.dart';
import 'package:dropweb/views/proxies/providers.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import 'common.dart';
import 'setting.dart';
import 'tab.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> with PageMixin {
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();
  bool _hasProviders = false;
  bool _isTab = false;

  Future<void> _pingAllGroups() async {
    final groups = ref.read(currentGroupsStateProvider).value;
    final allProxies = <Proxy>[];
    final seenNames = <String>{};

    for (final group in groups) {
      for (final proxy in group.all) {
        if (!seenNames.contains(proxy.name)) {
          seenNames.add(proxy.name);
          allProxies.add(proxy);
        }
      }
    }

    if (allProxies.isNotEmpty) {
      await delayTest(allProxies, null);
    }
  }

  @override
  List<Widget> get actions => [
        Consumer(
          builder: (_, ref, child) {
            final globalModeEnabled = ref.watch(globalModeEnabledProvider);
            if (!globalModeEnabled) return const SizedBox.shrink();
            return child!;
          },
          child: const _ModeSelectorAction(),
        ),
        const SearchOrderMarker(),
        if (_isTab)
          IconButton(
            onPressed: () {
              _proxiesTabKey.currentState?.scrollToGroupSelected();
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedTarget01,
              size: 24,
            ),
          ),
        if (!_isTab) ...[
          IconButton(
            onPressed: _pingAllGroups,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedWifiConnected01,
              size: 24,
            ),
          ),
          Consumer(
            builder: (_, ref, __) {
              final unfoldSet = ref.watch(unfoldSetProvider);
              final groupNames = ref.watch(
                currentGroupsStateProvider.select(
                  (state) => state.value.map((e) => e.name).toList(),
                ),
              );
              final allExpanded =
                  groupNames.isNotEmpty && groupNames.every(unfoldSet.contains);
              return IconButton(
                onPressed: () {
                  if (allExpanded) {
                    globalState.appController.updateCurrentUnfoldSet({});
                  } else {
                    globalState.appController
                        .updateCurrentUnfoldSet(groupNames.toSet());
                  }
                },
                icon: HugeIcon(
                  icon: allExpanded
                      ? HugeIcons.strokeRoundedArrowShrink
                      : HugeIcons.strokeRoundedArrowExpand01,
                  size: 24,
                ),
              );
            },
          ),
        ],
        CommonPopupBox(
          targetBuilder: (open) => IconButton(
            onPressed: () {
              open(
                offset: const Offset(0, 20),
              );
            },
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedMoreVertical,
              size: 24,
            ),
          ),
          popup: CommonPopupMenu(
            items: [
              PopupMenuItemData(
                label: appLocalizations.settings,
                onPressed: () {
                  showSheet(
                    context: context,
                    props: const SheetProps(
                      isScrollControlled: true,
                    ),
                    builder: (_, type) => AdaptiveSheetScaffold(
                      type: type,
                      body: const ProxiesSetting(),
                      title: appLocalizations.settings,
                    ),
                  );
                },
              ),
              if (_hasProviders)
                PopupMenuItemData(
                  label: appLocalizations.providers,
                  onPressed: () {
                    showExtend(
                      context,
                      builder: (_, type) => const ProvidersView(),
                    );
                  },
                ),
              if (!_isTab)
                PopupMenuItemData(
                  label: appLocalizations.iconConfiguration,
                  onPressed: () {
                    showExtend(
                      context,
                      builder: (_, type) => const _IconConfigView(),
                    );
                  },
                ),
            ],
          ),
        )
      ];

  @override
  Null Function(String value) get onSearch => (value) {
        ref.read(proxiesQueryProvider.notifier).value = value;
      };

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(proxiesQueryProvider.notifier).value = "";
      }
    });
  }

  @override
  DelayTestButton? get floatingActionButton => _isTab
      ? DelayTestButton(
          onClick: () async {
            await _proxiesTabKey.currentState?.delayTestCurrentGroup();
          },
        )
      : null;

  @override
  void initState() {
    ref.listenManual(
      proxiesActionsStateProvider,
      fireImmediately: true,
      (prev, next) {
        if (prev == next) {
          return;
        }
        if (next.pageLabel == PageLabel.proxies) {
          _hasProviders = next.hasProviders;
          _isTab = next.type == ProxiesType.tab;
          initPageState();
          return;
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(proxiesQueryProvider.notifier).value = "";
            }
          });
        }
      },
    );
    super.initState();
  }

  @override
  void initPageState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final commonScaffoldState = context.commonScaffoldState;
      commonScaffoldState?.actions = actions;
      commonScaffoldState?.floatingActionButton = floatingActionButton;
      commonScaffoldState?.onKeywordsUpdate = onKeywordsUpdate;
      commonScaffoldState?.updateSearchState(
        (_) => AppBarSearchState(
          onSearch: onSearch,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => state.type,
      ),
    );
    return switch (proxiesType) {
      ProxiesType.tab => ProxiesTabView(
          key: _proxiesTabKey,
        ),
      ProxiesType.list => const ProxiesListView(),
    };
  }
}

class _ModeSelectorAction extends ConsumerWidget {
  const _ModeSelectorAction();

  String _modeLabel(BuildContext context, Mode mode) => switch (mode) {
        Mode.rule => appLocalizations.rule,
        Mode.global => appLocalizations.global,
        Mode.direct => appLocalizations.direct,
      };

  List<List<dynamic>> _modeIcon(Mode mode) => switch (mode) {
        Mode.rule => HugeIcons.strokeRoundedTask01,
        Mode.global => HugeIcons.strokeRoundedGlobe02,
        Mode.direct => HugeIcons.strokeRoundedFlash,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );

    return CommonPopupBox(
      targetBuilder: (open) => IconButton(
        tooltip: _modeLabel(context, mode),
        onPressed: () => open(offset: const Offset(0, 20)),
        icon: HugeIcon(icon: _modeIcon(mode), size: 24),
      ),
      popup: CommonPopupMenu(
        items: [
          for (final item in Mode.values.where((m) => m != Mode.direct))
            PopupMenuItemData(
              label: _modeLabel(context, item),
              onPressed: () {
                globalState.appController.changeMode(item);
              },
            ),
        ],
      ),
    );
  }
}

class _IconConfigView extends ConsumerWidget {
  const _IconConfigView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconMap = ref.watch(proxiesStyleSettingProvider.select(
      (state) => state.iconMap,
    ));
    return CommonScaffold(
      title: appLocalizations.iconConfiguration,
      body: MapInputPage(
        title: appLocalizations.iconConfiguration,
        map: iconMap,
        keyLabel: appLocalizations.regExp,
        valueLabel: appLocalizations.icon,
        titleBuilder: (item) => Text(item.key),
        leadingBuilder: (item) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: CommonTargetIcon(
            src: item.value,
            size: 42,
          ),
        ),
        subtitleBuilder: (item) => Text(
          item.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onChange: (value) {
          ref.read(proxiesStyleSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  iconMap: value,
                ),
              );
        },
      ),
    );
  }
}
