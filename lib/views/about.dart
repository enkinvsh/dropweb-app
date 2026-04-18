import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

@immutable
class Contributor {
  const Contributor({
    required this.name,
    required this.avatar,
    required this.role,
  });
  final String name;
  final String avatar;
  final String role;
}

// -----------------------------------------------------------------------
// Credits roll — order matters. Files transfer through these people in
// sequence, and the last one (enkinvsh) never completes: the transfer
// hangs forever on him. That's the punchline.
// -----------------------------------------------------------------------
const _credits = <Contributor>[
  Contributor(
    name: 'chen08209',
    avatar: 'assets/images/avatars/chen08209.jpg',
    role: 'Original FlClash author',
  ),
  Contributor(
    name: 'pluralplay',
    avatar: 'assets/images/avatars/pluralplay.jpg',
    role: 'FlClashX maintainer',
  ),
  Contributor(
    name: 'kastov',
    avatar: 'assets/images/avatars/kastov.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'x_kit_',
    avatar: 'assets/images/avatars/x_kit_.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'katsukibtw',
    avatar: 'assets/images/avatars/katsukibtw.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'cool_coala',
    avatar: 'assets/images/avatars/cool_coala.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'arpic',
    avatar: 'assets/images/avatars/arpic.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'legiz',
    avatar: 'assets/images/avatars/legiz.jpg',
    role: 'contributor',
  ),
  Contributor(
    name: 'enkinvsh',
    avatar: 'assets/images/avatars/enkinvsh.jpg',
    role: 'dropweb',
  ),
];

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<void> _checkUpdate(BuildContext context) async {
    final commonScaffoldState = context.commonScaffoldState;
    if (commonScaffoldState?.mounted != true) return;
    final data = await commonScaffoldState?.loadingRun<Map<String, dynamic>?>(
      request.checkForUpdate,
      title: appLocalizations.checkUpdate,
    );
    globalState.appController.checkUpdateResultHandle(
      data: data,
      handleError: true,
    );
  }

  List<Widget> _buildMoreSection(BuildContext context) {
    final items = <Widget>[
      // Play Store policy forbids in-app update checks on Android —
      // store channel is the source of truth. Keep for desktop builds.
      if (!Platform.isAndroid)
        ListItem(
          title: Text(appLocalizations.checkUpdate),
          onTap: () => _checkUpdate(context),
          trailing: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
        ),
      ListItem(
        title: Text(appLocalizations.project),
        onTap: () => globalState.openUrl("https://github.com/$repository"),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      ListItem(
        title: Text(appLocalizations.originalRepository),
        onTap: () => globalState.openUrl(
          "https://github.com/pluralplay/FlClashX",
        ),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      ListItem(
        title: Text(appLocalizations.core),
        onTap: () => globalState.openUrl(
          "https://github.com/MetaCubeX/mihomo",
        ),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
    ];
    return generateSection(
      separated: false,
      title: appLocalizations.more,
      items: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ListTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EasterEggDetector(
              child: Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Image.asset(
                      'assets/images/icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        globalState.packageInfo.version,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      const _CoreVersionWidget(),
                    ],
                  )
                ],
              ),
              onEasterEgg: () => _showFileTransferGame(context),
            ),
            const SizedBox(height: 24),
            Text(
              appLocalizations.desc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              "Based on FlClashX, licensed under GPL-3.0",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ..._buildMoreSection(context),
    ];
    return Padding(
      padding: kMaterialListPadding.copyWith(top: 16, bottom: 16),
      child: generateListView(items),
    );
  }
}

class _CoreVersionWidget extends StatelessWidget {
  const _CoreVersionWidget();

  @override
  Widget build(BuildContext context) {
    final coreVersion = globalState.coreVersion;
    if (coreVersion == null || coreVersion.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      'Core: $coreVersion',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _EasterEggDetector extends StatefulWidget {
  const _EasterEggDetector({
    required this.child,
    required this.onEasterEgg,
  });
  final Widget child;
  final VoidCallback onEasterEgg;

  @override
  State<_EasterEggDetector> createState() => _EasterEggDetectorState();
}

class _EasterEggDetectorState extends State<_EasterEggDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 10) {
      widget.onEasterEgg();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _handleTap,
        child: widget.child,
      );
}

// -----------------------------------------------------------------------
// Easter egg: File Transfer Manager = hidden credits
//
// Each "file" being transferred is actually a contributor. Starts from
// chen08209 (upstream FlClash author), then pluralplay (FlClashX), then
// all contributors, ending on enkinvsh — where the transfer hangs forever.
//
// The list IS the credits roll. No separate "reveal" screen needed.
// -----------------------------------------------------------------------

void _showFileTransferGame(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _FileTransferDialog(),
  );
}

class _FileTransferDialog extends StatefulWidget {
  const _FileTransferDialog();

  @override
  State<_FileTransferDialog> createState() => _FileTransferDialogState();
}

class _FileTransferDialogState extends State<_FileTransferDialog> {
  // Transfer "files" = contributors, in credits order.
  static final _items = _credits;
  static final _lastIndex = _items.length - 1;

  int _current = 0;
  double _fileProgress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isHangingOnMe => _current == _lastIndex;

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_isHangingOnMe) {
          // Forever hang on enkinvsh. Slow stuttering progress that never
          // reaches 1.0 — the joke is the transfer literally cannot finish.
          if (_fileProgress < 0.87) {
            _fileProgress += 0.0015 + math.Random().nextDouble() * 0.001;
          } else {
            // Asymptote — tiny jitter, never completes.
            _fileProgress += (math.Random().nextDouble() - 0.5) * 0.0008;
            _fileProgress = _fileProgress.clamp(0.83, 0.88);
          }
        } else {
          _fileProgress += 0.035 + math.Random().nextDouble() * 0.025;
          if (_fileProgress >= 1.0) {
            _fileProgress = 0.0;
            _current++;
            if (_current > _lastIndex) _current = _lastIndex;
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final person = _items[_current];
    final overall = (_current + _fileProgress.clamp(0.0, 1.0)) / _items.length;

    return AlertDialog(
      title: const Text(
        'File Transfer Manager',
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Передача файла ${_current + 1} из ${_items.length}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                foregroundImage: AssetImage(person.avatar),
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  person.name[0].toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Onest',
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      person.name,
                      style: textTheme.bodyLarge?.copyWith(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      person.role,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _fileProgress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                _isHangingOnMe ? colorScheme.error : colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Всего', style: textTheme.labelSmall),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: overall.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          if (_isHangingOnMe)
            Text(
              'Ожидание ответа сервера…',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
            )
          else
            Text(
              'Подключено. Передача идёт.',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отменить'),
        ),
      ],
    );
  }
}
