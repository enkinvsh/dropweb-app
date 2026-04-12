import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/manager/hotkey_manager.dart';
import 'package:dropweb/manager/manager.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controller.dart';
import 'pages/pages.dart';

class Application extends ConsumerStatefulWidget {
  const Application({
    super.key,
  });

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateGroupTaskTimer;
  Timer? _autoUpdateProfilesTaskTimer;

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CommonPageTransitionsBuilder(),
      TargetPlatform.windows: CommonPageTransitionsBuilder(),
      TargetPlatform.linux: CommonPageTransitionsBuilder(),
      TargetPlatform.macOS: CommonPageTransitionsBuilder(),
    },
  );

  ColorScheme _getAppColorScheme({
    required Brightness brightness,
    int? primaryColor,
  }) =>
      ref.read(genColorSchemeProvider(brightness));

  @override
  void initState() {
    super.initState();

    if (Platform.isWindows) {
      windows?.enableDarkModeForApp();
    }

    _autoUpdateGroupTask();
    _autoUpdateProfilesTask();
    globalState.appController = AppController(context, ref);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final currentContext = globalState.navigatorKey.currentContext;
      if (currentContext != null) {
        globalState.appController = AppController(currentContext, ref);
      }
      await globalState.appController.init();
      globalState.appController.initLink();
      app?.initShortcuts();
    });
  }

  void _autoUpdateGroupTask() {
    _autoUpdateGroupTaskTimer = Timer(const Duration(milliseconds: 20000), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        globalState.appController.updateGroupsDebounce();
        _autoUpdateGroupTask();
      });
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await globalState.appController.autoUpdateProfiles();
      _autoUpdateProfilesTask();
    });
  }

  Widget _buildPlatformState(Widget child) {
    if (system.isDesktop) {
      return WindowManager(
        child: TrayManager(
          child: HotKeyManager(
            child: ProxyManager(
              child: child,
            ),
          ),
        ),
      );
    }
    return AndroidManager(
      child: TileManager(
        child: child,
      ),
    );
  }

  Widget _buildState(Widget child) => AppStateManager(
        child: ClashManager(
          child: ConnectivityManager(
            onConnectivityChanged: (results) async {
              if (!results.contains(ConnectivityResult.vpn)) {
                clashCore.closeConnections();
              }
              globalState.appController.updateLocalIp();
              globalState.appController.addCheckIpNumDebounce();
            },
            child: child,
          ),
        ),
      );

  Widget _buildPlatformApp(Widget child) {
    if (system.isDesktop) {
      return WindowHeaderContainer(
        child: child,
      );
    }
    return VpnManager(
      child: child,
    );
  }

  Widget _buildApp(Widget child) => MessageManager(
        child: ThemeManager(
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) => _buildPlatformState(
        _buildState(
          Consumer(
            builder: (_, ref, child) {
              final locale =
                  ref.watch(appSettingProvider.select((state) => state.locale));
              final themeProps = ref.watch(themeSettingProvider);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                navigatorKey: globalState.navigatorKey,
                checkerboardRasterCacheImages: false,
                checkerboardOffscreenLayers: false,
                showPerformanceOverlay: false,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate
                ],
                builder: (_, child) {
                  final Widget app = AppEnvManager(
                    child: _buildPlatformApp(
                      _buildApp(child!),
                    ),
                  );

                  if (Platform.isMacOS) {
                    return FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 500,
                        height: 800,
                        child: app,
                      ),
                    );
                  }

                  return app;
                },
                scrollBehavior: BaseScrollBehavior(),
                title: appName,
                locale: utils.getLocaleForString(locale),
                supportedLocales: AppLocalizations.delegate.supportedLocales,
                themeMode: themeProps.themeMode,
                theme: _buildThemeData(
                  brightness: Brightness.light,
                  primaryColor: themeProps.primaryColor,
                  pureBlack: false,
                ),
                darkTheme: _buildThemeData(
                  brightness: Brightness.dark,
                  primaryColor: themeProps.primaryColor,
                  pureBlack: themeProps.pureBlack,
                ),
                home: child,
              );
            },
            child: const HomePage(),
          ),
        ),
      );

  ThemeData _buildThemeData({
    required Brightness brightness,
    required int? primaryColor,
    required bool pureBlack,
  }) {
    final colorScheme = _getAppColorScheme(
      brightness: brightness,
      primaryColor: primaryColor,
    );
    const onest = TextTheme(
      displayLarge: TextStyle(fontFamily: 'Onest'),
      displayMedium: TextStyle(fontFamily: 'Onest'),
      displaySmall: TextStyle(fontFamily: 'Onest'),
      headlineLarge: TextStyle(fontFamily: 'Onest'),
      headlineMedium: TextStyle(fontFamily: 'Onest'),
      headlineSmall: TextStyle(fontFamily: 'Onest'),
      titleLarge: TextStyle(fontFamily: 'Onest'),
      titleMedium: TextStyle(fontFamily: 'Onest'),
      titleSmall: TextStyle(fontFamily: 'Onest'),
      bodyLarge: TextStyle(fontFamily: 'Onest'),
      bodyMedium: TextStyle(fontFamily: 'Onest'),
      bodySmall: TextStyle(fontFamily: 'Onest'),
      labelLarge: TextStyle(fontFamily: 'Onest'),
      labelMedium: TextStyle(fontFamily: 'Onest'),
      labelSmall: TextStyle(fontFamily: 'Onest'),
    );
    var scheme = pureBlack ? colorScheme.toPureBlack(true) : colorScheme;
    // LUMINA: override surfaces for dark theme — tactile void
    if (brightness == Brightness.dark) {
      scheme = scheme.copyWith(
        surface: Lumina.void_,
        surfaceContainerLowest: Lumina.surface1,
        surfaceContainerLow: Lumina.surface2,
        surfaceContainer: Lumina.surface3,
        surfaceContainerHigh: Lumina.surface4,
        surfaceContainerHighest: Lumina.surface5,
      );
    }
    return ThemeData(
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: scheme,
      textTheme: onest,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // LUMINA: cards use void-level elevation
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: Lumina.glassOpacity)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Lumina.radiusLg),
          side: brightness == Brightness.dark
              ? BorderSide(
                  color:
                      Colors.white.withValues(alpha: Lumina.glassBorderOpacity))
              : BorderSide.none,
        ),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    linkManager.destroy();
    _autoUpdateGroupTaskTimer?.cancel();
    _autoUpdateProfilesTaskTimer?.cancel();
    await clashCore.destroy();
    await globalState.appController.savePreferences();
    await globalState.appController.handleExit();
    super.dispose();
  }
}
