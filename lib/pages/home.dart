import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/views/dashboard/widgets/start_button.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
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

class _BottomBarWithConnect extends StatelessWidget {
  final Widget navigationBar;

  const _BottomBarWithConnect({required this.navigationBar});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 8,
      ),
      child: Row(
        children: [
          // Tab bar island — takes remaining space
          Expanded(child: _buildTabBarIsland(context)),
          const SizedBox(width: 10),
          // Connect button circle — same height
          _buildConnectCircle(context),
        ],
      ),
    );
  }

  Widget _buildTabBarIsland(BuildContext context) {
    // Extract the inner content from navigationBar
    // We rebuild it here to control the outer container
    return navigationBar;
  }

  Widget _buildConnectCircle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (isDark) {
      return RepaintBoundary(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: Lumina.glassShadow,
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: Lumina.glassBlur,
              child: Container(
                decoration: Lumina.glassCircle(),
                child: const StartButton(),
              ),
            ),
          ),
        ),
      );
    }

    // Light theme: solid surface, no blur
    return RepaintBoundary(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainer,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
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

  Widget _buildTabBarContent(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Lumina.radiusXl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: Lumina.glassBorderOpacity)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(navigationItems.length, (index) {
          final item = navigationItems[index];
          final isSelected = index == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                globalState.appController.toPage(item.label);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: 22,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    child: item.icon,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Intl.message(item.label.name),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Bioluminescent glow dot under selected tab (dark theme only)
                  if (isSelected && isDark)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 20,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 6),
                ],
              ),
            ),
          );
        }),
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
            borderRadius: BorderRadius.circular(Lumina.radiusXl),
            boxShadow: isDark
                ? Lumina.glassShadow
                : [
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Lumina.radiusXl),
            child: isDark
                ? BackdropFilter(
                    filter: Lumina.glassBlur,
                    child: _buildTabBarContent(context, colorScheme, isDark),
                  )
                : _buildTabBarContent(context, colorScheme, isDark),
          ),
        ),
      );
    }
    final showLabel = ref.watch(appSettingProvider).showLabel;
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
            icon: const Icon(Icons.menu),
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
