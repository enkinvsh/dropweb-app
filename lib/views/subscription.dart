import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart' hide Action;
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/mesh_background.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:dropweb/views/profiles/profiles.dart'
    show ProfileItem, ReorderableProfilesSheet;
import 'package:dropweb/views/profiles/scripts.dart';
import 'package:dropweb/views/proxies/common.dart';
import 'package:dropweb/views/proxies/list.dart';
import 'package:dropweb/views/proxies/providers.dart';
import 'package:dropweb/views/proxies/setting.dart';
import 'package:dropweb/views/proxies/tab.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<ProxiesTabViewState> _proxiesTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Profiles actions ──────────────────────────────────────────────────

  void _handleShowAddProfilePage() {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: AddProfileView(context: context),
        title: "${appLocalizations.add}${appLocalizations.profile}",
      ),
    );
  }

  Future<void> _updateProfiles() async {
    final profiles = globalState.config.profiles;
    final messages = [];
    final updateProfiles = profiles.map<Future>(
      (profile) async {
        if (profile.type == ProfileType.file) return;
        globalState.appController
            .setProfile(profile.copyWith(isUpdating: true));
        try {
          await globalState.appController.updateProfile(profile);
        } catch (e) {
          messages.add("${profile.label ?? profile.id}: $e \n");
          globalState.appController
              .setProfile(profile.copyWith(isUpdating: false));
        }
      },
    );
    final titleMedium = context.textTheme.titleMedium;
    await Future.wait(updateProfiles);
    if (messages.isNotEmpty) {
      globalState.showMessage(
        title: appLocalizations.tip,
        message: TextSpan(
          children: [
            for (final message in messages)
              TextSpan(text: message, style: titleMedium)
          ],
        ),
      );
    }
  }

  List<Widget> get _profilesActions => [
        IconButton(
            onPressed: _updateProfiles,
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24)),
        IconButton(
          onPressed: () =>
              showExtend(context, builder: (_, type) => const ScriptsView()),
          icon: Consumer(
            builder: (context, ref, __) {
              final isScriptMode = ref.watch(
                  scriptStateProvider.select((state) => state.realId != null));
              return HugeIcon(
                icon: HugeIcons.strokeRoundedFunctionCircle,
                size: 24,
                color: isScriptMode ? context.colorScheme.primary : null,
              );
            },
          ),
        ),
        IconButton(
          onPressed: () {
            final profiles = globalState.config.profiles;
            showSheet(
              context: context,
              builder: (_, type) =>
                  ReorderableProfilesSheet(type: type, profiles: profiles),
            );
          },
          icon: HugeIcon(icon: HugeIcons.strokeRoundedSorting01, size: 26),
        ),
      ];

  // ── Proxies actions ───────────────────────────────────────────────────

  bool get _isTab =>
      ref.read(proxiesStyleSettingProvider.select((s) => s.type)) ==
      ProxiesType.tab;

  bool get _hasProviders =>
      ref.read(providersProvider.select((s) => s.isNotEmpty));

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
    if (allProxies.isNotEmpty) await delayTest(allProxies, null);
  }

  List<Widget> get _proxiesActions {
    final isTab = _isTab;
    return [
      Consumer(
        builder: (_, ref, child) {
          final enabled = ref.watch(globalModeEnabledProvider);
          return enabled ? child! : const SizedBox.shrink();
        },
        child: const _ModeSelectorAction(),
      ),
      if (isTab)
        IconButton(
          onPressed: () => _proxiesTabKey.currentState?.scrollToGroupSelected(),
          icon: HugeIcon(icon: HugeIcons.strokeRoundedTarget01, size: 24),
        ),
      if (!isTab) ...[
        IconButton(
            onPressed: _pingAllGroups,
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedWifiConnected01, size: 24)),
        Consumer(builder: (_, ref, __) {
          final unfoldSet = ref.watch(unfoldSetProvider);
          final groupNames = ref.watch(currentGroupsStateProvider
              .select((s) => s.value.map((e) => e.name).toList()));
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
                size: 24),
          );
        }),
      ],
      CommonPopupBox(
        targetBuilder: (open) => IconButton(
          onPressed: () => open(offset: const Offset(0, 20)),
          icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 24),
        ),
        popup: CommonPopupMenu(items: [
          PopupMenuItemData(
            label: appLocalizations.settings,
            onPressed: () {
              showSheet(
                context: context,
                props: const SheetProps(isScrollControlled: true),
                builder: (_, type) => AdaptiveSheetScaffold(
                    type: type,
                    body: const ProxiesSetting(),
                    title: appLocalizations.settings),
              );
            },
          ),
          if (_hasProviders)
            PopupMenuItemData(
              label: appLocalizations.providers,
              onPressed: () => showExtend(context,
                  builder: (_, type) => const ProvidersView()),
            ),
        ]),
      ),
    ];
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isProfilesTab = _tabController.index == 0;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Lumina.void_ : Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: isDark,
      appBar: AppBar(
        title: Text(appLocalizations.subscription),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          ...(isProfilesTab ? _profilesActions : _proxiesActions),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: isProfilesTab
          ? FloatingActionButton(
              heroTag: null,
              onPressed: _handleShowAddProfilePage,
              child: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 24),
            )
          : (_isTab
              ? DelayTestButton(
                  onClick: () async {
                    await _proxiesTabKey.currentState?.delayTestCurrentGroup();
                  },
                )
              : null),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: MeshBackground()),
          Column(
            children: [
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(2),
                    dividerHeight: 0,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w400),
                    tabs: [
                      Tab(text: appLocalizations.profiles),
                      Tab(text: appLocalizations.proxies),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProfilesContent(onAdd: _handleShowAddProfilePage),
                    _ProxiesContent(proxiesTabKey: _proxiesTabKey),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Profiles content ──────────────────────────────────────────────────────

class _ProfilesContent extends ConsumerWidget {
  final VoidCallback onAdd;
  const _ProfilesContent({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesSelectorStateProvider);
    if (state.profiles.isEmpty) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 88),
        child: Grid(
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          crossAxisCount: state.columns,
          children: [
            for (int i = 0; i < state.profiles.length; i++)
              GridItem(
                child: ProfileItem(
                  key: Key(state.profiles[i].id),
                  profile: state.profiles[i],
                  groupValue: state.currentProfileId,
                  onChanged: (id) {
                    ref.read(currentProfileIdProvider.notifier).value = id;
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Proxies content ───────────────────────────────────────────────────────

class _ProxiesContent extends ConsumerWidget {
  final GlobalKey<ProxiesTabViewState> proxiesTabKey;
  const _ProxiesContent({required this.proxiesTabKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(patchClashConfigProvider.select((state) => state.mode));
    return switch (mode) {
      Mode.rule => const _SmartProxiesView(),
      Mode.direct => const _RulesProxiesView(),
      Mode.global => const _RulesProxiesView(),
    };
  }
}

// ── Smart mode view ───────────────────────────────────────────────────────

class _SmartProxiesView extends ConsumerWidget {
  const _SmartProxiesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (groups.isEmpty) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAiBrain02,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                Intl.message("smart"),
                style: context.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '·  ${groups.length} ${Intl.message("proxies").toLowerCase()}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Group summary cards
        for (final group in groups)
          _SmartGroupCard(group: group, isDark: isDark),
      ],
    );
  }
}

class _SmartGroupCard extends ConsumerWidget {
  final Group group;
  final bool isDark;
  const _SmartGroupCard({required this.group, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedName = group.realNow;
    final selectedProxy =
        group.all.where((p) => p.name == selectedName).firstOrNull;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Group icon — skip URL-based icons, show emoji or fallback
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: group.icon.isNotEmpty && !group.icon.startsWith('http')
                  ? Text(group.icon, style: const TextStyle(fontSize: 20))
                  : HugeIcon(
                      icon: HugeIcons.strokeRoundedWifiConnected01,
                      size: 20,
                      color: colorScheme.primary,
                    ),
            ),
            // Group name + selected proxy
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedProxy != null
                        ? '${selectedProxy.type} · $selectedName'
                        : selectedName.isNotEmpty
                            ? selectedName
                            : '...',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Delay badge
            if (selectedName.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final delay = ref.watch(getDelayProvider(
                    proxyName: selectedName,
                    testUrl: group.testUrl,
                  ));
                  if (delay == null || delay <= 0) {
                    return const SizedBox(width: 48);
                  }
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          utils.getDelayColor(delay)?.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$delay ms',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: utils.getDelayColor(delay),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Rules mode view ───────────────────────────────────────────────────────

class _RulesProxiesView extends ConsumerWidget {
  const _RulesProxiesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(currentGroupsStateProvider).value;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (groups.isEmpty) {
      return NullStatus(label: appLocalizations.nullProfileDesc);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFilter,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                Intl.message("rules"),
                style: context.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '·  ${groups.length} ${Intl.message("proxies").toLowerCase()}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        for (final group in groups)
          _RulesGroupCard(group: group, isDark: isDark),
      ],
    );
  }
}

class _RulesGroupCard extends ConsumerWidget {
  final Group group;
  final bool isDark;
  const _RulesGroupCard({required this.group, required this.isDark});

  void _openSelector(BuildContext context) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_, type) => _ProxySelectorSheet(group: group),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedName = group.realNow;
    final selectedProxy =
        group.all.where((p) => p.name == selectedName).firstOrNull;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openSelector(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: group.icon.isNotEmpty && !group.icon.startsWith('http')
                    ? Text(group.icon, style: const TextStyle(fontSize: 20))
                    : HugeIcon(
                        icon: HugeIcons.strokeRoundedWifiConnected01,
                        size: 20,
                        color: colorScheme.primary,
                      ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: context.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedProxy != null
                          ? '${selectedProxy.type} · $selectedName'
                          : selectedName.isNotEmpty
                              ? selectedName
                              : '...',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Delay badge
              if (selectedName.isNotEmpty)
                Consumer(
                  builder: (context, ref, _) {
                    final delay = ref.watch(getDelayProvider(
                      proxyName: selectedName,
                      testUrl: group.testUrl,
                    ));
                    if (delay == null || delay <= 0) {
                      return const SizedBox(width: 48);
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            utils.getDelayColor(delay)?.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$delay ms',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: utils.getDelayColor(delay),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 4),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Proxy selector sheet ──────────────────────────────────────────────────

class _ProxySelectorSheet extends ConsumerWidget {
  final Group group;
  const _ProxySelectorSheet({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedName = ref.watch(groupsProvider
        .select((groups) => groups.getGroup(group.name)?.realNow ?? ''));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              group.name,
              style: context.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: group.all.length,
              itemBuilder: (context, index) {
                final proxy = group.all[index];
                final isSelected = proxy.name == selectedName;
                return _ProxySelectorRow(
                  proxy: proxy,
                  testUrl: group.testUrl,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () {
                    globalState.appController.changeProxy(
                      groupName: group.name,
                      proxyName: proxy.name,
                    );
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _ProxySelectorRow extends ConsumerWidget {
  final Proxy proxy;
  final String? testUrl;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ProxySelectorRow({
    required this.proxy,
    required this.testUrl,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final delay = ref.watch(getDelayProvider(
      proxyName: proxy.name,
      testUrl: testUrl,
    ));

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.06)
            : null,
        child: Row(
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  size: 18,
                  color: colorScheme.primary,
                ),
              )
            else
              const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proxy.name,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colorScheme.primary : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    proxy.type,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (delay != null && delay > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: utils.getDelayColor(delay)?.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$delay ms',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: utils.getDelayColor(delay),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Mode selector ─────────────────────────────────────────────────────────

class _ModeSelectorAction extends ConsumerWidget {
  const _ModeSelectorAction();

  static const _modeOrder = [Mode.rule, Mode.direct, Mode.global];

  String _label(BuildContext context, Mode mode) => switch (mode) {
        Mode.rule => Intl.message("smart"),
        Mode.direct => Intl.message("rules"),
        Mode.global => Intl.message("global"),
      };

  List<List<dynamic>> _icon(Mode mode) => switch (mode) {
        Mode.rule => HugeIcons.strokeRoundedAiBrain02,
        Mode.direct => HugeIcons.strokeRoundedFilter,
        Mode.global => HugeIcons.strokeRoundedGlobe02,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(patchClashConfigProvider.select((state) => state.mode));
    return CommonPopupBox(
      targetBuilder: (open) => IconButton(
        tooltip: _label(context, mode),
        onPressed: () => open(offset: const Offset(0, 20)),
        icon: HugeIcon(icon: _icon(mode), size: 24),
      ),
      popup: CommonPopupMenu(
        items: [
          for (final item in _modeOrder)
            PopupMenuItemData(
              label: _label(context, item),
              onPressed: () => globalState.appController.changeMode(item),
            ),
        ],
      ),
    );
  }
}
