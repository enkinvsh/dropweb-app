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
import 'package:dropweb/views/proxies/providers.dart';
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
        actions: const [SizedBox(width: 8)],
      ),
      body: Stack(
        children: [
          if (isDark) const Positioned.fill(child: MeshBackground()),
          Column(
            children: [
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _GlassTabBar(
                  controller: _tabController,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  tabs: [
                    appLocalizations.profiles,
                    appLocalizations.proxies,
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProfilesContent(onAdd: _handleShowAddProfilePage),
                    const _ProxiesContent(),
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

Future<void> _refreshProfiles(BuildContext context) async {
  final profiles = globalState.config.profiles;
  final messages = <String>[];
  await Future.wait(profiles.map((profile) async {
    if (profile.type == ProfileType.file) return;
    globalState.appController.setProfile(profile.copyWith(isUpdating: true));
    try {
      await globalState.appController.updateProfile(profile);
    } catch (e) {
      messages.add("${profile.label ?? profile.id}: $e \n");
      globalState.appController.setProfile(profile.copyWith(isUpdating: false));
    }
  }));
  if (messages.isNotEmpty && context.mounted) {
    globalState.showMessage(
      title: appLocalizations.tip,
      message: TextSpan(
        children: [
          for (final msg in messages)
            TextSpan(text: msg, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ProfilesContent extends ConsumerWidget {
  final VoidCallback onAdd;
  const _ProfilesContent({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesSelectorStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _AddProfileCard(onTap: onAdd, isDark: isDark),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshProfiles(context),
      color: colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        children: [
          Grid(
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
              GridItem(
                child: _AddProfileCard(onTap: onAdd, isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _AddProfileCard({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: colorScheme.primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Proxies content ───────────────────────────────────────────────────────

class _ProxiesContent extends StatelessWidget {
  const _ProxiesContent();

  @override
  Widget build(BuildContext context) {
    // FlClashX-original behavior: the proxies UI is the same for all
    // three modes (rule / direct / global). Mode only changes mihomo
    // routing, never the on-screen proxy list. The bottom mode bar
    // (_ModeBottomBar) watches mode internally for its tab highlight.
    return const Column(
      children: [
        Expanded(child: _RulesProxiesView()),
        _ModeBottomBar(),
      ],
    );
  }
}

Future<void> _pingAllProxies(WidgetRef ref) async {
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

// ── Proxies view (shared across all 3 modes) ─────────────────────────────

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

    return RefreshIndicator(
      onRefresh: () => _pingAllProxies(ref),
      color: colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final group in groups)
            _RulesGroupCard(group: group, isDark: isDark),
        ],
      ),
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
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openSelector(context),
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
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
                          color: utils
                              .getDelayColor(delay)
                              ?.withValues(alpha: 0.15),
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
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 14,
                    color: isDark
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.primary,
                  ),
                ),
              ],
            ),
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

// ── Glass tab bar ─────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  final bool isDark;
  final ColorScheme colorScheme;
  final List<String> tabs;

  const _GlassTabBar({
    required this.controller,
    required this.isDark,
    required this.colorScheme,
    required this.tabs,
  });

  Widget _buildContent() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: Lumina.glassBorderOpacity)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: isDark
              ? colorScheme.primary.withValues(alpha: 0.15)
              : colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Lumina.radiusLg - 6),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerHeight: 0,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
        tabs: [for (final label in tabs) Tab(text: label)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        boxShadow: isDark ? Lumina.glassShadow : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        child: isDark
            ? BackdropFilter(
                filter: Lumina.glassBlur,
                child: _buildContent(),
              )
            : _buildContent(),
      ),
    );
  }
}

// ── Mode bottom bar ───────────────────────────────────────────────────────

const _modeOrder = [Mode.rule, Mode.direct, Mode.global];

String _modeLabel(Mode mode) => switch (mode) {
      Mode.rule => Intl.message("rules"),
      Mode.direct => Intl.message("direct"),
      Mode.global => Intl.message("global"),
    };

class _ModeBottomBar extends ConsumerWidget {
  const _ModeBottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(patchClashConfigProvider.select((state) => state.mode));
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Lumina.radiusLg),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: Lumina.glassBorderOpacity)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final m in _modeOrder)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => globalState.appController.changeMode(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m == mode
                        ? (isDark
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : colorScheme.primary.withValues(alpha: 0.12))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Lumina.radiusLg - 6),
                  ),
                  child: Text(
                    _modeLabel(m),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: m == mode ? FontWeight.w600 : FontWeight.w400,
                      color: m == mode
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          boxShadow: isDark ? Lumina.glassShadow : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          child: isDark
              ? BackdropFilter(filter: Lumina.glassBlur, child: content)
              : content,
        ),
      ),
    );
  }
}

// ── Shared body widgets for desktop pages ─────────────────────────────────

class SharedProxiesBody extends StatelessWidget {
  const SharedProxiesBody({super.key});

  @override
  Widget build(BuildContext context) {
    // Same content for all three modes — see _ProxiesContent comment.
    return const Column(
      children: [
        Expanded(child: _RulesProxiesView()),
        _ModeBottomBar(),
      ],
    );
  }
}

class SharedProfilesBody extends ConsumerWidget {
  const SharedProfilesBody({super.key});

  void _openAdd(BuildContext context) {
    showExtend(
      context,
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        body: AddProfileView(context: context),
        title: "${appLocalizations.add}${appLocalizations.profile}",
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesSelectorStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (state.profiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child:
              _AddProfileCard(onTap: () => _openAdd(context), isDark: isDark),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshProfiles(context),
      color: colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        children: [
          Grid(
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
              GridItem(
                child: _AddProfileCard(
                    onTap: () => _openAdd(context), isDark: isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
