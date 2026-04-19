import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dropweb/common/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

@immutable
class Contributor {
  const Contributor({
    required this.name,
    required this.avatar,
    required this.role,
    this.link,
  });
  final String name;
  final String avatar;
  final String role;
  final String? link;
}

// Order = credits roll. kinvsh must stay last: the easter-egg game
// exits the app on his file.
const _credits = <Contributor>[
  Contributor(
    name: 'chen08209',
    avatar: 'assets/images/avatars/chen08209.jpg',
    role: 'Original FlClash author',
    link: 'https://github.com/chen08209',
  ),
  Contributor(
    name: 'pluralplay',
    avatar: 'assets/images/avatars/pluralplay.jpg',
    role: 'FlClashX maintainer',
    link: 'https://github.com/pluralplay',
  ),
  Contributor(
    name: 'kastov',
    avatar: 'assets/images/avatars/kastov.jpg',
    role: 'contributor',
    link: 'https://github.com/kastov',
  ),
  Contributor(
    name: 'x_kit_',
    avatar: 'assets/images/avatars/x_kit_.jpg',
    role: 'contributor',
    link: 'https://github.com/this-xkit',
  ),
  Contributor(
    name: 'katsukibtw',
    avatar: 'assets/images/avatars/katsukibtw.jpg',
    role: 'contributor',
    link: 'https://github.com/katsukibtw',
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
    name: 'kinvsh',
    avatar: 'assets/images/avatars/enkinvsh.jpg',
    role: 'dropweb',
    link: 'https://github.com/enkinvsh',
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
      // "Thanks" is now a single tappable entry that opens a full credits
      // sheet — no parade of avatars on the main About page.
      ListItem(
        leading: HugeIcon(icon: HugeIcons.strokeRoundedFavourite, size: 24),
        title: Text(appLocalizations.gratitude),
        onTap: () => _showCreditsSheet(context),
        trailing: HugeIcon(icon: HugeIcons.strokeRoundedLink01, size: 24),
      ),
      // Play Store forbids in-app update checks on Android. Keep for desktop.
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
            const _AppHeader(),
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

// -----------------------------------------------------------------------
// App header: tap anywhere on the logo + name block to flip 3D and swap
// between dropweb icon / name and the author's avatar / handle "kinvsh".
// -----------------------------------------------------------------------

class _AppHeader extends StatefulWidget {
  const _AppHeader();

  @override
  State<_AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<_AppHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flip = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isAnimating) return;
    if (_controller.value >= 0.5) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  // Open the front-face primary link: project repo.
  void _openFrontPrimary() => globalState.openUrl(
        'https://github.com/$repository',
      );

  // Open the back-face primary link: author's github.
  void _openBackPrimary() => globalState.openUrl(
        'https://github.com/enkinvsh',
      );

  // Open the back-face secondary link: project landing page.
  void _openBackSecondary() => globalState.openUrl('https://dropweb.org');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _flip,
      builder: (_, __) {
        final t = _flip.value;
        final angle = t * math.pi;
        final showFront = t < 0.5;

        // Avatar / logo column — tap toggles flip.
        final avatar = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: showFront
                ? Image.asset(
                    'assets/images/icon.png',
                    width: 64,
                    height: 64,
                  )
                : ClipOval(
                    child: Image.asset(
                      'assets/images/avatars/enkinvsh.jpg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        );

        // Text column — each line is its own tap target opening a link.
        final textColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: showFront ? _openFrontPrimary : _openBackPrimary,
              child: Text(
                showFront ? appName : 'kinvsh',
                style: textTheme.headlineSmall,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: showFront ? _openFrontPrimary : _openBackSecondary,
              child: Text(
                showFront ? globalState.packageInfo.version : 'dropweb',
                style: textTheme.labelLarge?.copyWith(
                  decoration: showFront ? null : TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (showFront) const _CoreVersionWidget(),
          ],
        );

        Widget face = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            avatar,
            const SizedBox(width: 4),
            textColumn,
          ],
        );

        // Back face is counter-rotated so its content isn't mirrored.
        if (!showFront) {
          face = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: face,
          );
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: face,
          ),
        );
      },
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

// -----------------------------------------------------------------------
// Credits sheet — full list with avatars + roles + links, opened only
// when the user explicitly taps "Благодарность" in the About menu.
// -----------------------------------------------------------------------

void _showCreditsSheet(BuildContext context) {
  showSheet(
    context: context,
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: appLocalizations.gratitude,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              // kinvsh is the flip-side of the dropweb logo, not a credit entry.
              for (final c in _credits.where((c) => c.name != 'kinvsh'))
                SizedBox(
                  width: 80,
                  child: _CreditAvatar(person: c),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CreditAvatar extends StatelessWidget {
  const _CreditAvatar({required this.person});
  final Contributor person;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        if (person.link != null) globalState.openUrl(person.link!);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            foregroundImage: AssetImage(person.avatar),
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              person.name[0].toUpperCase(),
              style: TextStyle(
                fontFamily: 'Onest',
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            person.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Onest',
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            person.role,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Onest',
              fontSize: 9,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Game: drag contributor cards from SOURCE → TARGET folder, one by one,
// in credits order. Last card (kinvsh) closes the app on drop.
// -----------------------------------------------------------------------

/// Entry point for the hidden File Transfer game. Exposed so the nav-bar
/// easter egg (10 taps on Dashboard) can reuse it.
void startFileTransferGame(BuildContext context) =>
    _startFileTransferGame(context);

void _startFileTransferGame(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const _FileTransferGame(),
      fullscreenDialog: true,
    ),
  );
}

class _FileTransferGame extends StatefulWidget {
  const _FileTransferGame();

  @override
  State<_FileTransferGame> createState() => _FileTransferGameState();
}

class _FileTransferGameState extends State<_FileTransferGame> {
  int _currentIndex = 0;
  bool _closing = false;

  Contributor get _current => _credits[_currentIndex];
  bool get _isLast => _currentIndex == _credits.length - 1;

  Future<void> _handleAccepted(Contributor dropped) async {
    if (dropped.name != _current.name) return;

    if (_isLast) {
      // The joke: transferring kinvsh kills the process.
      setState(() => _closing = true);
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 650));
      await globalState.appController.handleExit();
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _currentIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final total = _credits.length;

    if (_closing) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.power_settings_new_rounded,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Передача kinvsh…',
                style: textTheme.titleMedium?.copyWith(fontFamily: 'Onest'),
              ),
              const SizedBox(height: 4),
              Text(
                'Соединение потеряно.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Transfer'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Перенеси ${_currentIndex + 1} из $total',
                style: textTheme.titleMedium?.copyWith(fontFamily: 'Onest'),
              ),
              const SizedBox(height: 4),
              Text(
                'Тащи карточку из «contributors/» в «shipped/».',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _currentIndex / total,
                  minHeight: 4,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 24),
              _FolderHeader(
                label: 'contributors/',
                icon: Icons.folder_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              _ContributorCard(person: _current),
              const SizedBox(height: 28),
              _FolderHeader(
                label: 'shipped/',
                icon: Icons.folder_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DragTarget<Contributor>(
                  onWillAcceptWithDetails: (d) => d.data.name == _current.name,
                  onAcceptWithDetails: (d) => _handleAccepted(d.data),
                  builder: (_, candidate, __) {
                    final hovering = candidate.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: hovering
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.5,
                              )
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hovering
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: hovering ? 2 : 1,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          hovering ? 'Отпусти.' : 'Сюда.',
                          style: textTheme.bodyLarge?.copyWith(
                            fontFamily: 'Onest',
                            color: hovering
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: 'Onest',
                color: color,
              ),
        ),
      ],
    );
  }
}

class _ContributorCard extends StatelessWidget {
  const _ContributorCard({required this.person});
  final Contributor person;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final card = Material(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
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
            Icon(
              Icons.drag_indicator_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );

    return Draggable<Contributor>(
      data: person,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 32,
          child: Transform.rotate(angle: -0.03, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: card),
      child: card,
    );
  }
}
