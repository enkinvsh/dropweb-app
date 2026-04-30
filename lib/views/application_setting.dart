import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/providers/providers.dart' show runTimeProvider;
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' hide context;
import '../services/log_buffer.dart';
import '../services/log_uploader.dart';
import '../services/parazitx_manager.dart';
import '../services/vk_auth_service.dart';
import 'captcha_screen.dart';
import 'parazitx/primary_cta.dart';
import 'vk_login_screen.dart';

class OpenLogsFolderItem extends ConsumerWidget {
  const OpenLogsFolderItem({super.key});

  Future<void> _openLogsFolder() async {
    try {
      final homePath = await appPath.homeDirPath;
      final logsPath = join(homePath, 'logs');
      final logsDir = Directory(logsPath);

      // Create logs directory if it doesn't exist
      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      // Open the folder based on platform
      if (Platform.isWindows) {
        await Process.run('explorer', [logsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [logsPath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [logsPath]);
      }
    } catch (e) {
      commonPrint.log('Failed to open logs folder: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(appLocalizations.openLogsFolder),
        leading: HugeIcon(icon: HugeIcons.strokeRoundedFolderOpen, size: 24),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16),
        onTap: _openLogsFolder,
      );
}

class ResetAppItem extends ConsumerWidget {
  const ResetAppItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListItem(
        title: Text(
          appLocalizations.clearData,
          style: TextStyle(
            color: context.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedDelete01,
          size: 24,
          color: context.colorScheme.error,
        ),
        onTap: () async {
          final res = await globalState.showMessage(
            title: appLocalizations.clearData,
            message: TextSpan(
              text: appLocalizations.clearDataTip,
              style: TextStyle(
                color: context.colorScheme.onSurface,
              ),
            ),
          );
          if (res == true) {
            await globalState.appController.handleClear();
            system.exit();
          }
        },
      );
}

class OverrideProviderSettingsItem extends ConsumerWidget {
  const OverrideProviderSettingsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListItem.switchItem(
          title: Text(appLocalizations.overrideProviderSettings),
          subtitle: Text(appLocalizations.overrideProviderSettingsDesc),
          delegate: SwitchDelegate(
            value: overrideProviderSettings,
            onChanged: (value) {
              ref.read(appSettingProvider.notifier).updateState(
                    (state) => state.copyWith(
                      overrideProviderSettings: value,
                    ),
                  );
            },
          ),
        ),
        if (!overrideProviderSettings)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedInformationCircle,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appLocalizations.managedByProvider,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CloseConnectionsItem extends ConsumerWidget {
  const CloseConnectionsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final closeConnections = ref.watch(
      appSettingProvider.select((state) => state.closeConnections),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.autoCloseConnections),
      subtitle: Text(appLocalizations.autoCloseConnectionsDesc),
      delegate: SwitchDelegate(
        value: closeConnections,
        onChanged: (value) async {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  closeConnections: value,
                ),
              );
        },
      ),
    );
  }
}

class UsageItem extends ConsumerWidget {
  const UsageItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final onlyStatisticsProxy = ref.watch(
      appSettingProvider.select((state) => state.onlyStatisticsProxy),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.onlyStatisticsProxy),
      subtitle: Text(appLocalizations.onlyStatisticsProxyDesc),
      delegate: SwitchDelegate(
        value: onlyStatisticsProxy,
        onChanged: (bool value) async {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  onlyStatisticsProxy: value,
                ),
              );
        },
      ),
    );
  }
}

class MinimizeItem extends ConsumerWidget {
  const MinimizeItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimizeOnExit = ref.watch(
      appSettingProvider.select((state) => state.minimizeOnExit),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ListItem.switchItem(
        title: Text(appLocalizations.minimizeOnExit),
        subtitle: Text(appLocalizations.minimizeOnExitDesc),
        delegate: SwitchDelegate(
          value: minimizeOnExit,
          onChanged: isEnabled
              ? (bool value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          minimizeOnExit: value,
                        ),
                      );
                }
              : null,
        ),
      ),
    );
  }
}

class AutoLaunchItem extends ConsumerWidget {
  const AutoLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoLaunch = ref.watch(
      appSettingProvider.select((state) => state.autoLaunch),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ListItem.switchItem(
        title: Text(appLocalizations.autoLaunch),
        subtitle: Text(appLocalizations.autoLaunchDesc),
        delegate: SwitchDelegate(
          value: autoLaunch,
          onChanged: isEnabled
              ? (bool value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          autoLaunch: value,
                        ),
                      );
                }
              : null,
        ),
      ),
    );
  }
}

class SilentLaunchItem extends ConsumerWidget {
  const SilentLaunchItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final silentLaunch = ref.watch(
      appSettingProvider.select((state) => state.silentLaunch),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ListItem.switchItem(
        title: Text(appLocalizations.silentLaunch),
        subtitle: Text(appLocalizations.silentLaunchDesc),
        delegate: SwitchDelegate(
          value: silentLaunch,
          onChanged: isEnabled
              ? (bool value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          silentLaunch: value,
                        ),
                      );
                }
              : null,
        ),
      ),
    );
  }
}

class AutoRunItem extends ConsumerWidget {
  const AutoRunItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoRun = ref.watch(
      appSettingProvider.select((state) => state.autoRun),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ListItem.switchItem(
        title: Text(appLocalizations.autoRun),
        subtitle: Text(appLocalizations.autoRunDesc),
        delegate: SwitchDelegate(
          value: autoRun,
          onChanged: isEnabled
              ? (bool value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          autoRun: value,
                        ),
                      );
                }
              : null,
        ),
      ),
    );
  }
}

class HiddenItem extends ConsumerWidget {
  const HiddenItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(
      appSettingProvider.select((state) => state.hidden),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.exclude),
      subtitle: Text(appLocalizations.excludeDesc),
      delegate: SwitchDelegate(
        value: hidden,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  hidden: value,
                ),
              );
        },
      ),
    );
  }
}

class AnimateTabItem extends ConsumerWidget {
  const AnimateTabItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnimateToPage = ref.watch(
      appSettingProvider.select((state) => state.isAnimateToPage),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.tabAnimation),
      subtitle: Text(appLocalizations.tabAnimationDesc),
      delegate: SwitchDelegate(
        value: isAnimateToPage,
        onChanged: (value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  isAnimateToPage: value,
                ),
              );
        },
      ),
    );
  }
}

class OpenLogsItem extends ConsumerWidget {
  const OpenLogsItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openLogs = ref.watch(
      appSettingProvider.select((state) => state.openLogs),
    );
    return ListItem.switchItem(
      title: Text(appLocalizations.logcat),
      subtitle: Text(appLocalizations.logcatDesc),
      delegate: SwitchDelegate(
        value: openLogs,
        onChanged: (bool value) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  openLogs: value,
                ),
              );
        },
      ),
    );
  }
}

class AutoCheckUpdateItem extends ConsumerWidget {
  const AutoCheckUpdateItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoCheckUpdate = ref.watch(
      appSettingProvider.select((state) => state.autoCheckUpdate),
    );
    final overrideProviderSettings = ref.watch(
      appSettingProvider.select((state) => state.overrideProviderSettings),
    );
    final isEnabled = overrideProviderSettings;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: ListItem.switchItem(
        title: Text(appLocalizations.autoCheckUpdate),
        subtitle: Text(appLocalizations.autoCheckUpdateDesc),
        delegate: SwitchDelegate(
          value: autoCheckUpdate,
          onChanged: isEnabled
              ? (bool value) {
                  ref.read(appSettingProvider.notifier).updateState(
                        (state) => state.copyWith(
                          autoCheckUpdate: value,
                        ),
                      );
                }
              : null,
        ),
      ),
    );
  }
}

class _UserCancelled implements Exception {}

/// Internal state-machine for the ParazitX section.
enum _ParazitXState {
  /// VK session not present — toggle is OFF, prompt to log in.
  notLoggedIn,

  /// VK session exists, tunnel is inactive.
  loggedIn,

  /// Optimistic toggle already moved to ON; activate() running in background.
  connecting,

  /// Tunnel is up and routing traffic.
  active,
}

/// Visual layout for [ParazitXSectionItem].
///
/// The activation widget owns one source of truth for VK login, captcha,
/// mihomo-stop dialog, optimistic toggle and error snackbars. Two
/// surfaces consume that logic:
///
/// * [settingsTile] — list/switch row used inside `ApplicationSettingView`.
///   Subtitle copy and trailing logout row preserved.
/// * [primaryCta] — single full-width primary button used on the
///   standalone `VK Звонки` page hero. No switch row, no logout link
///   (logout lives in settings only on this surface).
enum ParazitXSectionLayout {
  settingsTile,
  primaryCta,
}

class ParazitXSectionItem extends ConsumerStatefulWidget {
  const ParazitXSectionItem({
    super.key,
    this.layout = ParazitXSectionLayout.settingsTile,
  });

  final ParazitXSectionLayout layout;

  @override
  ConsumerState<ParazitXSectionItem> createState() =>
      _ParazitXSectionItemState();
}

class _ParazitXSectionItemState extends ConsumerState<ParazitXSectionItem> {
  bool _parazitxEnabled = false;
  bool _vkConnected = false;
  bool _captchaOpen = false;
  StreamSubscription<bool>? _readySub;
  StreamSubscription<String>? _captchaSub;
  _ParazitXState _state = _ParazitXState.notLoggedIn;

  @override
  void initState() {
    super.initState();
    _parazitxEnabled = ParazitXManager.isActive;
    if (_parazitxEnabled) _state = _ParazitXState.active;
    _readySub = ParazitXManager.tunnelReadyStream.listen((ready) {
      if (!mounted) return;
      setState(() {
        if (!ready && _parazitxEnabled) {
          // Tunnel dropped — show reconnecting state (manager auto-reconnects)
          _state = _ParazitXState.connecting;
        } else if (ready && _parazitxEnabled) {
          // Tunnel reconnected — show active state
          _state = _ParazitXState.active;
        }
      });
    });
    _captchaSub = ParazitXManager.captchaStream.listen(_openCaptcha);
    _checkVkSession();
  }

  @override
  void dispose() {
    _readySub?.cancel();
    _captchaSub?.cancel();
    super.dispose();
  }

  Future<void> _openCaptcha(String url) async {
    if (_captchaOpen || !mounted) return;
    _captchaOpen = true;
    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => CaptchaScreen(proxyUrl: url)),
      );
      // ParazitXPage listens for tunnelReady and does the popUntil-isFirst.
    } finally {
      _captchaOpen = false;
    }
  }

  Future<void> _checkVkSession() async {
    final connected = await VkAuthService.hasValidSession();
    if (!mounted) return;
    setState(() {
      _vkConnected = connected;
      if (ParazitXManager.isActive) {
        _state = _ParazitXState.active;
        _parazitxEnabled = true;
      } else if (connected) {
        _state = _ParazitXState.loggedIn;
      } else {
        _state = _ParazitXState.notLoggedIn;
      }
    });
  }

  String get _subtitle {
    switch (_state) {
      case _ParazitXState.notLoggedIn:
        return 'Войдите в VK для активации';
      case _ParazitXState.loggedIn:
        return 'VK: сессия подключена';
      case _ParazitXState.connecting:
        return 'Подключение…';
      case _ParazitXState.active:
        return 'Режим стабильности активен';
    }
  }

  /// Show a SnackBar with a human-readable message for [error].
  void _showErrorSnackBar(ActivateError error) {
    if (!mounted) return;
    String msg;
    SnackBarAction? action;
    switch (error) {
      case ActivateError.noCookies:
        msg = 'Войдите в VK сначала';
      case ActivateError.networkError:
        msg = 'Нет соединения с сервером';
      case ActivateError.serverError:
        msg = 'Ошибка сервера, попробуйте позже';
      case ActivateError.vkUnauthorized:
        msg = 'VK-сессия истекла — войдите заново';
        action = SnackBarAction(
          label: 'Войти',
          onPressed: _openVkLogin,
        );
      case ActivateError.tunnelError:
        msg = 'Не удалось включить режим стабильности';
    }
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: action,
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Open [VkLoginScreen] and update state when the user logs in.
  Future<void> _openVkLogin() async {
    final success = await Navigator.push<bool>(
      this.context,
      MaterialPageRoute(builder: (_) => const VkLoginScreen()),
    );
    if (success == true && mounted) {
      setState(() {
        _vkConnected = true;
        _state = _ParazitXState.loggedIn;
      });
    }
  }

  /// Ask the user to stop the mihomo VPN, then actually stop it and wait
  /// until [runTimeProvider] reports the tunnel closed. Returns once mihomo
  /// is fully down (or after a timeout, to avoid hanging the toggle).
  Future<void> _confirmStopMihomoAndWait() async {
    final confirmed = await showDialog<bool>(
      context: this.context,
      builder: (ctx) => AlertDialog(
        title: const Text('Основное подключение будет выключено'),
        content: const Text(
          'Для режима стабильности VK Звонков нужен отдельный локальный '
          'VPN-канал. Основной VPN будет остановлен перед включением режима.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (confirmed != true) throw _UserCancelled();
    await globalState.appController.updateStatus(false);
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (ref.read(runTimeProvider) != null &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Handle the toggle tap with optimistic UI.
  Future<void> _handleToggle(bool value) async {
    developer.log(
        '[ParazitX][activation] toggle entry: value=$value state=$_state vkConnected=$_vkConnected',
        name: 'ParazitX');
    LogBuffer.instance.add(
        '[ParazitX][activation] toggle entry: value=$value state=$_state vk=$_vkConnected');
    debugPrint(
        '[ParazitX][activation] _handleToggle value=$value state=$_state vk=$_vkConnected');
    // Debounce: ignore taps while activation is already in flight.
    if (_state == _ParazitXState.connecting) {
      developer.log(
          '[ParazitX][activation] toggle: already connecting, ignored',
          name: 'ParazitX');
      return;
    }

    if (value) {
      // ── Turning ON ──────────────────────────────────────────────────────
      if (!_vkConnected) {
        await _openVkLogin();
        // After returning, check if login succeeded.
        if (!mounted || !_vkConnected) return;
      }

      // Android allows only one VpnService at a time. If mihomo is running,
      // stop it and wait for teardown before bringing ParazitXVpnService up.
      final mihomoRunning = ref.read(runTimeProvider) != null;
      if (mihomoRunning) {
        try {
          await _confirmStopMihomoAndWait();
        } on _UserCancelled {
          return;
        }
        if (!mounted) return;
      }

      // Optimistic: move the toggle immediately so the user has feedback.
      setState(() {
        _parazitxEnabled = true;
        _state = _ParazitXState.connecting;
      });

      developer.log(
          '[ParazitX][activation] toggle: calling ParazitXManager.activate()',
          name: 'ParazitX');
      LogBuffer.instance
          .add('[ParazitX][activation] toggle: invoking activate()');
      debugPrint('[ParazitX][activation] _handleToggle -> activate()');
      final error = await ParazitXManager.activate();
      developer.log(
          '[ParazitX][activation] toggle: activate() returned error=$error',
          name: 'ParazitX');
      LogBuffer.instance
          .add('[ParazitX][activation] toggle: activate() done error=$error');
      debugPrint(
          '[ParazitX][activation] _handleToggle activate() returned error=$error');
      if (!mounted) return;

      if (error == null) {
        // Success
        setState(() => _state = _ParazitXState.active);
      } else {
        // Rollback
        setState(() {
          _parazitxEnabled = false;
          _state = _vkConnected
              ? _ParazitXState.loggedIn
              : _ParazitXState.notLoggedIn;
        });
        _showErrorSnackBar(error);
      }
    } else {
      // ── Turning OFF ─────────────────────────────────────────────────────
      await ParazitXManager.deactivate();
      if (mounted) {
        setState(() {
          _parazitxEnabled = false;
          _state = _vkConnected
              ? _ParazitXState.loggedIn
              : _ParazitXState.notLoggedIn;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.layout) {
      case ParazitXSectionLayout.settingsTile:
        return _buildSettingsTile(context);
      case ParazitXSectionLayout.primaryCta:
        return _buildPrimaryCta(context);
    }
  }

  Widget _buildSettingsTile(BuildContext context) {
    final isConnecting = _state == _ParazitXState.connecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListItem.switchItem(
          title: const Text('Режим стабильности VK Звонков'),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_subtitle),
              if (isConnecting) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          delegate: SwitchDelegate(
            value: _parazitxEnabled,
            // onChanged is always non-null — we debounce internally in
            // _handleToggle. Passing null would grey-out the switch and
            // cause the "frozen toggle" UX bug.
            onChanged: _handleToggle,
          ),
        ),
        if (_vkConnected) ...[
          const Divider(height: 0),
          ListItem(
            title: const Text('Выйти из VK'),
            leading: const Icon(Icons.logout),
            onTap: () async {
              // Capture before async gaps.
              final messenger = ScaffoldMessenger.of(context);
              // Deactivate tunnel BEFORE clearing cookies so the rotation
              // timer stops and the SOCKS5 port is freed.
              if (ParazitXManager.isActive) {
                await ParazitXManager.deactivate();
              }
              await VkAuthService.clearCookies();
              if (mounted) {
                setState(() {
                  _vkConnected = false;
                  _parazitxEnabled = false;
                  _state = _ParazitXState.notLoggedIn;
                });
                messenger.showSnackBar(
                  const SnackBar(content: Text('Вы вышли из VK')),
                );
              }
            },
          ),
        ],
      ],
    );
  }

  /// Calm, banking-grade single-button CTA used on the standalone VK
  /// Звонки page. Reuses the same activation logic as the settings
  /// tile — never duplicate `_handleToggle`, the captcha listener, the
  /// mihomo-stop dialog, or the optimistic flow.
  Widget _buildPrimaryCta(BuildContext context) {
    // Source-of-truth override: `_state` is owned by this widget and
    // updated via `_checkVkSession`/`_handleToggle`/`_readySub`. None of
    // those refresh when `ParazitXManager.isActive` flips while we are
    // mounted but mid-`_checkVkSession` (cookies-loading async gap), or
    // when the page remounts after a hot restart between activation
    // success and the next `tunnelReadyStream` event. In those windows
    // `_state` stays at `loggedIn` while the manager already considers
    // the mode on. Pure UI override — no semantics changed: the CTA
    // simply mirrors the manager when the manager disagrees.
    final effectiveState =
        ParazitXManager.isActive ? _ParazitXState.active : _state;
    switch (effectiveState) {
      case _ParazitXState.notLoggedIn:
        return PrimaryCta(
          label: 'Войти и включить',
          supportingText: 'Нужна сессия VK.',
          onPressed: () => _handleToggle(true),
        );
      case _ParazitXState.loggedIn:
        return PrimaryCta(
          label: 'Включить режим',
          supportingText: 'Сессия VK подключена.',
          onPressed: () => _handleToggle(true),
        );
      case _ParazitXState.connecting:
        return const PrimaryCta(
          label: 'Подключаем...',
          supportingText: 'Обычно до 15 секунд.',
          onPressed: null,
          showProgress: true,
        );
      case _ParazitXState.active:
        return PrimaryCta(
          label: 'Отключить',
          supportingText: 'Режим активен.',
          tonal: true,
          onPressed: () => _handleToggle(false),
        );
    }
  }
}

class SendParazitXLogsItem extends StatefulWidget {
  const SendParazitXLogsItem({super.key});

  @override
  State<SendParazitXLogsItem> createState() => _SendParazitXLogsItemState();
}

class _SendParazitXLogsItemState extends State<SendParazitXLogsItem> {
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final result = await LogUploader.send();
    if (!mounted) return;
    setState(() => _sending = false);
    if (result.isOk) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Отправлено, ID: ${result.id}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 6),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Не удалось отправить: ${result.error}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: const Text('📤 Отправить логи ParazitX'),
      subtitle: const Text('Для диагностики проблем'),
      leading: _sending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : HugeIcon(icon: HugeIcons.strokeRoundedUpload01, size: 24),
      trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 16),
      onTap: _sending ? null : _send,
    );
  }
}

class ApplicationSettingView extends StatelessWidget {
  const ApplicationSettingView({super.key});

  String getLocaleString(Locale? locale) {
    if (locale == null) return appLocalizations.defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [
      OverrideProviderSettingsItem(),
      MinimizeItem(),
      if (system.isDesktop) ...[
        AutoLaunchItem(),
        SilentLaunchItem(),
      ],
      AutoRunItem(),
      if (Platform.isAndroid) ...[
        HiddenItem(),
      ],
      AnimateTabItem(),
      OpenLogsItem(),
      CloseConnectionsItem(),
      UsageItem(),
      AutoCheckUpdateItem(),
      if (system.isDesktop) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OpenLogsFolderItem(),
        ),
      ],
      if (Platform.isAndroid) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SendParazitXLogsItem(),
        ),
      ],
      Padding(
        padding: EdgeInsets.only(top: system.isDesktop ? 0 : 16),
        child: ResetAppItem(),
      ),
    ];
    return ListView.separated(
      itemBuilder: (_, index) => items[index],
      separatorBuilder: (_, __) => const Divider(
        height: 0,
      ),
      itemCount: items.length,
    );
  }
}
