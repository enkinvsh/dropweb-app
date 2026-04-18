import 'dart:async';
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/l10n/l10n.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/about.dart';
import 'package:dropweb/views/access.dart';
import 'package:dropweb/views/application_setting.dart';
import 'package:dropweb/views/config/config.dart';
import 'package:dropweb/views/hotkey.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show dirname, join;

import 'package:dropweb/pages/send_to_tv_page.dart';

import 'developer.dart';
import 'theme.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolboxViewState();
}

class _ToolboxViewState extends ConsumerState<ToolsView> {
  ListItem<dynamic> _buildNavigationMenuItem(NavigationItem navigationItem) =>
      ListItem.open(
        leading: navigationItem.icon,
        title: Text(Intl.message(navigationItem.label.name)),
        subtitle: navigationItem.description != null
            ? Text(Intl.message(navigationItem.description!))
            : null,
        delegate: OpenDelegate(
          title: Intl.message(navigationItem.label.name),
          widget: navigationItem.view,
        ),
      );

  Widget _buildNavigationMenu(List<NavigationItem> navigationItems) => Column(
        children: [
          for (final navigationItem in navigationItems) ...[
            _buildNavigationMenuItem(navigationItem),
            navigationItems.last != navigationItem
                ? const Divider(
                    height: 0,
                  )
                : Container(),
          ]
        ],
      );

  List<Widget> _getOtherList(BuildContext context, bool enableDeveloperMode) =>
      generateSection(
        title: AppLocalizations.of(context).other,
        items: [
          const _DisclaimerItem(),
          if (enableDeveloperMode) const _DeveloperItem(),
          const _InfoItem(),
        ],
      );

  List<Widget> _getSettingList(
    BuildContext context,
    bool enableDeveloperMode,
  ) =>
      generateSection(
        title: null,
        items: [
          const _LocaleItem(),
          const _ThemeItem(),
          if (system.isDesktop) const _HotkeyItem(),
          if (Platform.isWindows) const _LoopbackItem(),
          if (Platform.isAndroid) const _AccessItem(),
          if (Platform.isAndroid) const _TvItem(),
          if (enableDeveloperMode) const _ConfigItem(),
          if (enableDeveloperMode) const _SettingItem(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(a: state.locale, b: state.developerMode),
      ),
    );
    final appLocale = AppLocalizations.of(context);
    final items = [
      Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(moreToolsSelectorStateProvider);
          if (state.navigationItems.isEmpty) {
            return Container();
          }
          return Column(
            children: [
              ListHeader(title: appLocale.more),
              _buildNavigationMenu(state.navigationItems)
            ],
          );
        },
      ),
      ..._getSettingList(context, vm2.b),
      ..._getOtherList(context, vm2.b),
    ];
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, index) => items[index],
      padding: const EdgeInsets.only(bottom: 20),
    );
  }
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(BuildContext context, Locale? locale) {
    if (locale == null) return AppLocalizations.of(context).defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = AppLocalizations.of(context);
    final locale =
        ref.watch(appSettingProvider.select((state) => state.locale));
    final subTitle = locale ?? appLocale.defaultText;
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedGlobe02, size: 24),
      title: Text(appLocale.language),
      subtitle: Text(Intl.message(subTitle)),
      delegate: OptionsDelegate(
        title: appLocale.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (locale) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(locale: locale?.toString()),
              );
        },
        textBuilder: (locale) => _getLocaleString(context, locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedEdgeStyle, size: 24),
      title: Text(appLocale.theme),
      subtitle: Text(appLocale.themeDesc),
      delegate: OpenDelegate(
        title: appLocale.theme,
        widget: const ThemeView(),
      ),
    );
  }
}

class _HotkeyItem extends StatelessWidget {
  const _HotkeyItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedKeyboard, size: 24),
      title: Text(appLocale.hotkeyManagement),
      subtitle: Text(appLocale.hotkeyManagementDesc),
      delegate: OpenDelegate(
        title: appLocale.hotkeyManagement,
        widget: const HotKeyView(),
      ),
    );
  }
}

class _LoopbackItem extends StatelessWidget {
  const _LoopbackItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, size: 24),
      title: Text(appLocale.loopback),
      subtitle: Text(appLocale.loopbackDesc),
      onTap: () {
        windows?.runas(
          '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
          "",
        );
      },
    );
  }
}

class _AccessItem extends StatelessWidget {
  const _AccessItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedListView, size: 24),
      title: Text(appLocale.accessControl),
      subtitle: Text(appLocale.accessControlDesc),
      delegate: OpenDelegate(
        title: appLocale.accessControl,
        widget: const AccessView(),
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedEdit01, size: 24),
      title: Text(appLocale.basicConfig),
      subtitle: Text(appLocale.basicConfigDesc),
      delegate: OpenDelegate(
        title: appLocale.override,
        widget: const ConfigView(),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedSettings02, size: 24),
      title: Text(appLocale.application),
      subtitle: Text(appLocale.applicationDesc),
      delegate: OpenDelegate(
        title: appLocale.application,
        widget: const ApplicationSettingView(),
      ),
    );
  }
}

class _DisclaimerItem extends StatelessWidget {
  const _DisclaimerItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedLegalHammer, size: 24),
      title: Text(appLocale.disclaimer),
      onTap: () async {
        final isDisclaimerAccepted =
            await globalState.appController.showDisclaimer();
        if (!isDisclaimerAccepted) {
          globalState.appController.handleExit();
        }
      },
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading:
          HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, size: 24),
      title: Text(appLocale.about),
      delegate: OpenDelegate(
        title: appLocale.about,
        widget: const AboutView(),
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedCpu, size: 24),
      title: Text(appLocale.developerMode),
      delegate: OpenDelegate(
        title: appLocale.developerMode,
        widget: const DeveloperView(),
      ),
    );
  }
}

class _TvItem extends ConsumerStatefulWidget {
  const _TvItem();

  @override
  ConsumerState<_TvItem> createState() => _TvItemState();
}

class _TvItemState extends ConsumerState<_TvItem> {
  String? _profileUrl;
  String? _lastLoadedProfileId;

  Future<void> _ensureUrl(Profile profile) async {
    if (_lastLoadedProfileId == profile.id) return;
    _lastLoadedProfileId = profile.id;
    final url = await preferences.getProfileUrl(profile);
    if (!mounted) return;
    setState(() {
      _profileUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    final profile = ref.watch(currentProfileProvider);
    if (profile != null) {
      unawaited(_ensureUrl(profile));
    }
    final url = _profileUrl;
    final hasUrl = profile != null && url != null && url.isNotEmpty;
    return ListItem(
      leading: HugeIcon(icon: HugeIcons.strokeRoundedTv01, size: 24),
      title: Text(appLocale.connectTv),
      subtitle: Text(appLocale.connectTvDesc),
      onTap: hasUrl
          ? () {
              BaseNavigator.push(
                context,
                SendToTvPage(profileUrl: url),
              );
            }
          : null,
    );
  }
}
