import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/views/about.dart' show startFileTransferGame;
import 'package:dropweb/views/dashboard/widgets/magic_rings.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

typedef OnSelected = void Function(int index);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => HomeBackScope(
        child: Consumer(
          builder: (_, ref, child) {
            final state = ref.watch(homeStateProvider);
            final viewMode = state.viewMode;
            final navigationItems = state.navigationItems;
            final pageLabel = state.pageLabel;
            final index = navigationItems.lastIndexWhere(
              (element) => element.label == pageLabel,
            );
            final currentIndex = index == -1 ? 0 : index;
            final navigationBar = CommonNavigationBar(
              viewMode: viewMode,
              navigationItems: navigationItems,
              currentIndex: currentIndex,
            );
            final bottomNavigationBar = viewMode == ViewMode.mobile
                ? _BottomBarWithConnect(navigationBar: navigationBar)
                : null;
            final sideNavigationBar =
                viewMode != ViewMode.mobile ? navigationBar : null;
            return CommonScaffold(
              key: globalState.homeScaffoldKey,
              title: pageLabel == PageLabel.dashboard
                  ? ''
                  : Intl.message(pageLabel.name),
              sideNavigationBar: sideNavigationBar,
              body: child!,
              bottomNavigationBar: bottomNavigationBar,
            );
          },
          child: _HomePageView(),
        ),
      );
}

class _HomePageView extends ConsumerStatefulWidget {
  const _HomePageView();

  @override
  ConsumerState createState() => _HomePageViewState();
}

class _HomePageViewState extends ConsumerState<_HomePageView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _pageIndex,
      keepPage: true,
    );
    ref.listenManual(currentPageLabelProvider, (prev, next) {
      if (prev != next) {
        _toPage(next);
      }
    });
    ref.listenManual(currentNavigationsStateProvider, (prev, next) {
      if (prev?.value.length != next.value.length) {
        _updatePageController();
      }
    });
  }

  int get _pageIndex {
    final navigationItems = ref.read(currentNavigationsStateProvider).value;
    return navigationItems.indexWhere(
      (item) => item.label == globalState.appState.pageLabel,
    );
  }

  _toPage(PageLabel pageLabel, [bool ignoreAnimateTo = false]) async {
    if (!mounted) {
      return;
    }
    final navigationItems = ref.read(currentNavigationsStateProvider).value;
    final index = navigationItems.indexWhere((item) => item.label == pageLabel);
    if (index == -1) {
      return;
    }
    final isAnimateToPage = ref.read(appSettingProvider).isAnimateToPage;
    final isMobile = ref.read(isMobileViewProvider);
    if (isAnimateToPage && isMobile && !ignoreAnimateTo) {
      await _pageController.animateToPage(
        index,
        duration: kTabScrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _pageController.jumpToPage(index);
    }
  }

  _updatePageController() {
    final pageLabel = globalState.appState.pageLabel;
    _toPage(pageLabel, true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationItems = ref.watch(currentNavigationsStateProvider).value;
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: navigationItems.length,
      // onPageChanged: (index) {
      //   debouncer.call(DebounceTag.pageChange, () {
      //     WidgetsBinding.instance.addPostFrameCallback((_) {
      //       if (_pageIndex != index) {
      //         final pageLabel = navigationItems[index].label;
      //         _toPage(pageLabel, true);
      //       }
      //     });
      //   });
      // },
      itemBuilder: (_, index) {
        final navigationItem = navigationItems[index];
        return KeepScope(
          keep: navigationItem.keep,
          key: Key(navigationItem.label.name),
          child: navigationItem.view,
        );
      },
    );
  }
}

class _BottomBarWithConnect extends ConsumerWidget {
  final Widget navigationBar;

  const _BottomBarWithConnect({required this.navigationBar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasProfile =
        ref.watch(profilesProvider.select((state) => state.isNotEmpty));

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 8,
      ),
      child: Row(
        children: [
          if (hasProfile)
            SizedBox(
              width: 140,
              child: navigationBar,
            ),
          const Spacer(),
          _ConnectCircle(),
        ],
      ),
    );
  }
}

/// Connect button — glass circle. Reports its screen position via
/// [connectButtonCenter] so [MagicRingsOverlay] can draw rings from it.
///
/// No glow — just glassShadow always.
class _ConnectCircle extends ConsumerStatefulWidget {
  const _ConnectCircle();

  @override
  ConsumerState<_ConnectCircle> createState() => _ConnectCircleState();
}

/// Global notifier for the connect button's screen-space center.
/// Written by [_ConnectCircle], read by [MagicRingsOverlay].
final connectButtonCenter = ValueNotifier<Offset?>(null);

class _ConnectCircleState extends ConsumerState<_ConnectCircle>
    with WidgetsBindingObserver {
  final _key = GlobalKey();

  void _reportPosition() {
    if (!mounted) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final center =
        box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
    if (connectButtonCenter.value != center) {
      connectButtonCenter.value = center;
    }
  }

  void _schedulePostFrameReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportPosition());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Report position once after first layout — the button doesn't move
    // within a stable layout, so the old per-frame tracking loop was pure
    // waste (it was burning 2-4 ms every frame on findRenderObject +
    // localToGlobal + notifier writes).
    _schedulePostFrameReport();

    // Profile availability toggles the nav-row in [_BottomBarWithConnect],
    // which shifts the connect button horizontally. Re-anchor the rings
    // origin whenever profile presence changes.
    ref.listenManual<bool>(
      profilesProvider.select((profiles) => profiles.isNotEmpty),
      (_, __) => _schedulePostFrameReport(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedulePostFrameReport();
  }

  /// Window resize on desktop / orientation change on mobile shifts the
  /// button without touching inherited dependencies, so we need a metrics
  /// callback to re-anchor the rings origin.
  @override
  void didChangeMetrics() {
    _schedulePostFrameReport();
  }

  @override
  void didUpdateWidget(covariant _ConnectCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Any rebuild of the parent could shift the button (e.g. theme switch
    // changes border thickness, padding, etc). Cheap to re-report.
    _schedulePostFrameReport();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    connectButtonCenter.value = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    const buttonSize = 64.0; // same as navbar

    if (!isDark) {
      return RepaintBoundary(
        key: _key,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.surfaceContainer,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const StartButton(),
        ),
      );
    }

    return RepaintBoundary(
      key: _key,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: Lumina.glassShadow,
        ),
        child: ClipOval(
          // BackdropFilter disabled for perf test
          child: Container(
            decoration: Lumina.glassCircle(),
            child: const StartButton(),
          ),
        ),
      ),
    );
  }
}

/// Developer mode activation via 5 rapid CONSECUTIVE taps on the Settings
/// tab. Any tap on another tab (or a pause >3s) resets the counter so
/// users bouncing between Dashboard and Settings don't accidentally
/// unlock dev mode.
int _devTapCount = 0;
DateTime _devTapLast = DateTime(0);
const _devTapThreshold = 5;
const _devTapWindow = Duration(seconds: 3);

void _resetDevTapCount() {
  _devTapCount = 0;
  _devTapLast = DateTime(0);
}

/// Hidden File Transfer game — triggered by 10 rapid CONSECUTIVE taps on
/// the Dashboard tab. Any tap on another tab (or >3s pause) resets.
int _eggTapCount = 0;
DateTime _eggTapLast = DateTime(0);
const _eggTapThreshold = 10;
const _eggTapWindow = Duration(seconds: 3);

void _resetEasterEggTaps() {
  _eggTapCount = 0;
  _eggTapLast = DateTime(0);
}

void _handleDashboardTap(BuildContext context) {
  final now = DateTime.now();
  if (now.difference(_eggTapLast) > _eggTapWindow) {
    _eggTapCount = 0;
  }
  _eggTapLast = now;
  _eggTapCount++;
  if (_eggTapCount >= _eggTapThreshold) {
    _eggTapCount = 0;
    startFileTransferGame(context);
  }
}

void _handleDevTap(BuildContext context, WidgetRef ref) {
  final now = DateTime.now();
  if (now.difference(_devTapLast) > _devTapWindow) {
    _devTapCount = 0;
  }
  _devTapLast = now;
  _devTapCount++;
  final alreadyEnabled = ref.read(appSettingProvider).developerMode;
  if (alreadyEnabled) return;
  if (_devTapCount >= _devTapThreshold) {
    _devTapCount = 0;
    ref.read(appSettingProvider.notifier).updateState(
          (state) => state.copyWith(developerMode: true),
        );
    globalState.showNotifier(appLocalizations.developerModeEnableTip);
  }
}

class CommonNavigationBar extends ConsumerWidget {
  final ViewMode viewMode;
  final List<NavigationItem> navigationItems;
  final int currentIndex;

  const CommonNavigationBar({
    super.key,
    required this.viewMode,
    required this.navigationItems,
    required this.currentIndex,
  });

  static const _icons = <PageLabel, (IconData, IconData)>{
    PageLabel.dashboard: (Icons.dashboard_outlined, Icons.dashboard_rounded),
    PageLabel.tools: (Icons.settings_outlined, Icons.settings_rounded),
  };

  static IconData _navIcon(PageLabel label, bool selected) {
    final pair = _icons[label];
    if (pair == null) return Icons.circle_outlined;
    return selected ? pair.$2 : pair.$1;
  }

  Widget _buildTabBarContent(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    WidgetRef ref,
  ) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Lumina.radiusXxl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: Lumina.glassBorderOpacity)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(navigationItems.length, (index) {
            final item = navigationItems[index];
            final isSelected = index == currentIndex;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  globalState.appController.toPage(item.label);
                  if (item.label == PageLabel.tools) {
                    _handleDevTap(context, ref);
                    _resetEasterEggTaps();
                  } else if (item.label == PageLabel.dashboard) {
                    _handleDashboardTap(context);
                    _resetDevTapCount();
                  } else {
                    _resetDevTapCount();
                    _resetEasterEggTaps();
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : colorScheme.primary.withValues(alpha: 0.12))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Lumina.radiusXxl - 6),
                  ),
                  child: Center(
                    child: Icon(
                      _navIcon(item.label, isSelected),
                      size: 24,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    if (viewMode == ViewMode.mobile) {
      final colorScheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Lumina.radiusXxl),
            boxShadow: isDark
                ? Lumina.glassShadow
                : const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Lumina.radiusXxl),
            // BackdropFilter disabled for perf test
            child: _buildTabBarContent(context, colorScheme, isDark, ref),
          ),
        ),
      );
    }
    final showLabel =
        ref.watch(appSettingProvider.select((state) => state.showLabel));
    return Material(
      color: context.colorScheme.surfaceContainer,
      child: Column(
        children: [
          // App logo at the top of sidebar
          if (!Platform.isMacOS) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircleAvatar(
                      foregroundImage: AssetImage("assets/images/icon.png"),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  if (showLabel) ...[
                    const SizedBox(height: 4),
                    Text(
                      appName,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
          Expanded(
            child: ScrollConfiguration(
              behavior: HiddenBarScrollBehavior(),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: context.colorScheme.surfaceContainer,
                    selectedIconTheme: IconThemeData(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                    selectedLabelTextStyle:
                        context.textTheme.labelLarge!.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    unselectedLabelTextStyle:
                        context.textTheme.labelLarge!.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                    destinations: navigationItems
                        .map(
                          (e) => NavigationRailDestination(
                            icon: e.icon,
                            label: Text(
                              Intl.message(e.label.name),
                            ),
                          ),
                        )
                        .toList(),
                    onDestinationSelected: (index) {
                      globalState.appController
                          .toPage(navigationItems[index].label);
                    },
                    extended: false,
                    selectedIndex: currentIndex,
                    labelType: showLabel
                        ? NavigationRailLabelType.all
                        : NavigationRailLabelType.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          IconButton(
            onPressed: () {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(
                      showLabel: !state.showLabel,
                    ),
                  );
            },
            icon: HugeIcon(icon: HugeIcons.strokeRoundedMenu01, size: 24),
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    );
  }
}

class _NavigationBarDefaultsM3 extends NavigationBarThemeData {
  _NavigationBarDefaultsM3(this.context)
      : super(
          height: 80.0,
          elevation: 3.0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surfaceContainer;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get surfaceTintColor => Colors.transparent;

  @override
  WidgetStateProperty<IconThemeData?>? get iconTheme =>
      WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
                size: 24.0,
                color: states.contains(WidgetState.disabled)
                    ? _colors.onSurfaceVariant.opacity38
                    : states.contains(WidgetState.selected)
                        ? _colors.onSecondaryContainer
                        : _colors.onSurfaceVariant,
              ));

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  ShapeBorder? get indicatorShape => const StadiumBorder();

  @override
  WidgetStateProperty<TextStyle?>? get labelTextStyle =>
      WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => _textTheme.labelMedium!.apply(
              overflow: TextOverflow.ellipsis,
              color: states.contains(WidgetState.disabled)
                  ? _colors.onSurfaceVariant.opacity38
                  : states.contains(WidgetState.selected)
                      ? _colors.onSurface
                      : _colors.onSurfaceVariant));
}

class HomeBackScope extends StatelessWidget {
  final Widget child;

  const HomeBackScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      return CommonPopScope(
        onPop: () async {
          final canPop = Navigator.canPop(context);
          if (canPop) {
            Navigator.pop(context);
          } else {
            await globalState.appController.handleBackOrExit();
          }
          return false;
        },
        child: child,
      );
    }
    return child;
  }
}
