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

// ======================================================================
// HIDDEN GAME — File Transfer
// ======================================================================
//
// Triggered by 10 rapid taps on the Dashboard nav-bar entry. The user has
// to drag every contributor card from `contributors/` into `shipped/`,
// in credits order, while the game gently fights back. The last card
// (kinvsh) closes the app on drop. That's the joke.
//
// Friction mechanics layered on top of the basic drag-and-drop:
//
//   1. Wandering target — `shipped/` zone drifts in a Lissajous-like path
//      using two sines on different frequencies. Wander amp + freq both
//      jump while a card is in flight, so the target actively flees.
//
//   2. Shrinking target — when not dragging, `shipped/` fills the whole
//      bottom area (so it reads as "obviously the target"). The MOMENT a
//      drag starts, the zone shrinks to a 220-dp square in the middle of
//      that area — the surrounding empty space becomes a miss zone where
//      a release shatters the card.
//
//   3. Anti-drag pings — speech bubble cycles through self-aware taunts
//      every ~1.1s while dragging ("куда?", "не туда", "точно?", …). The
//      kinvsh card switches to escalating dread ("НЕТ", "умоляю", …).
//
// Polish on success:
//   - Drop zone pulses (scale 1.0→1.08→1.0).
//   - 14-particle confetti burst (CustomPainter) in primary/tertiary tones.
//   - Animated progress bar (350ms ease-out, not snap).
//   - "+1 shipped" floats up from the zone and fades.
//   - Medium haptic (heavy is reserved for failure / kinvsh).
//
// Polish on failure (release outside the target):
//   - Shard burst at the drop point — same particle painter as confetti
//     but with muted greys + slimmer rectangles + heavy haptic.
//   - The shard origin is the global drop offset from onDraggableCanceled,
//     so shards explode exactly where the user fumbled.
//
// Surprises (the user does NOT see these coming):
//
//   A. CHEN BOOMERANG — chen08209's first "successful" drop is a fakeout.
//      The card pops back out of `shipped/` after ~320ms with a red banner
//      "не так быстро" / "chen08209 вернулся. попробуй ещё раз." and the
//      progress bar rolls back to 0. Triggers ONCE. Goal: make the player
//      think the game glitched the first time they win.
//
//   B. KINVSH GHOST COUNTER — while kinvsh is hovering the drop zone
//      (onWillAcceptWithDetails fires repeatedly during hover), the
//      "Перенеси 9 из 9" counter starts cycling through nonsense:
//      "9 из 13" → "9 из ∞" → "? из ?". Pure typographic dread. Stops
//      the moment the card leaves the zone.
//
//   C. KINVSH GLITCH EXIT — instead of the calm "Соединение потеряно",
//      dropping kinvsh triggers a 4-flash black/red sequence (~120ms each)
//      followed by a fake terminal stack trace ("kernel panic: unexpected
//      contributor", etc) before the app actually quits. ~1.5s of drama.

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

class _FileTransferGameState extends State<_FileTransferGame>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  // --- drag-state ---
  bool _isDragging = false;
  int _pingIndex = 0;
  Timer? _pingTimer;

  // --- kinvsh dramatic exit ---
  bool _glitching = false;
  int _glitchStep = 0;

  // --- anti-drag ping copy ---
  static const _pingMessages = [
    'куда?',
    'не туда',
    'точно?',
    'вернись',
    'это больно',
    'ты уверен?',
    'неет',
    'стоп',
  ];
  static const _kinvshPings = [
    'НЕТ.',
    'пожалуйста',
    'не надо',
    'это конец',
    'умоляю',
  ];

  // --- animation controllers ---
  late final AnimationController _wanderCtrl; // endless wander (4s)
  late final AnimationController _progressCtrl; // 350ms bar update
  late final AnimationController _pulseCtrl; // 250ms zone pulse
  late final AnimationController _confettiCtrl; // 700ms confetti
  late final AnimationController _floatCtrl; // 600ms +1 float
  late final AnimationController _shardCtrl; // 900ms shard burst

  late Animation<double> _progressAnim; // reassigned per accept
  late final Animation<double> _pulseScale;
  late final Animation<double> _floatOpacity;
  late final Animation<double> _floatDy;

  List<_Particle> _particles = [];
  bool _showConfetti = false;
  bool _showFloat = false;

  List<_Particle> _shardParticles = [];
  bool _showShards = false;
  Offset _shardOrigin = Offset.zero;

  // SURPRISE A — chen boomerang armed once.
  bool _chenBoomerangArmed = true;
  bool _chenBoomerangActive = false;

  // SURPRISE B — kinvsh ghost counter.
  Timer? _ghostCounterTimer;
  int _ghostCounterStep = 0;
  static const _ghostCounterFrames = ['9 из 9', '9 из 13', '9 из ∞', '? из ?'];

  Contributor get _current => _credits[_currentIndex];
  bool get _isLast => _currentIndex == _credits.length - 1;

  @override
  void initState() {
    super.initState();

    _wanderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _showConfetti = false);
        }
      });

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _floatOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_floatCtrl);
    _floatDy = Tween<double>(begin: 0.0, end: -44.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeOut),
    );
    _floatCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showFloat = false);
      }
    });

    _shardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _showShards = false);
        }
      });
  }

  @override
  void dispose() {
    _wanderCtrl.dispose();
    _progressCtrl.dispose();
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    _floatCtrl.dispose();
    _shardCtrl.dispose();
    _pingTimer?.cancel();
    _ghostCounterTimer?.cancel();
    super.dispose();
  }

  // ---- drag lifecycle ---------------------------------------------------

  void _onDragStarted() {
    setState(() {
      _isDragging = true;
      _pingIndex = 0;
    });
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      final msgs = _isLast ? _kinvshPings : _pingMessages;
      setState(() => _pingIndex = (_pingIndex + 1) % msgs.length);
    });
  }

  void _onDragEnded() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _ghostCounterTimer?.cancel();
    _ghostCounterTimer = null;
    if (mounted) {
      setState(() {
        _isDragging = false;
        _ghostCounterStep = 0;
      });
    }
  }

  /// Card released outside any DragTarget — `endOffset` is global, convert
  /// to local so the shard painter places debris at the right spot.
  void _onDragCanceled(Velocity v, Offset endOffset) {
    _onDragEnded();
    final box = context.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(endOffset) ?? endOffset;
    HapticFeedback.heavyImpact();
    _spawnShards();
    setState(() {
      _showShards = true;
      _shardOrigin = local;
    });
    _shardCtrl.forward(from: 0);
  }

  void _spawnShards() {
    final cs = Theme.of(context).colorScheme;
    final rng = math.Random();
    final palette = [
      cs.outlineVariant,
      cs.onSurfaceVariant,
      cs.surfaceContainerHighest,
      cs.error.withValues(alpha: 0.55),
    ];
    _shardParticles = List.generate(18, (_) {
      return _Particle(
        angle: rng.nextDouble() * 2 * math.pi,
        speed: 140.0 + rng.nextDouble() * 280.0,
        color: palette[rng.nextInt(palette.length)],
        size: 3.0 + rng.nextDouble() * 6.0,
        rotationSpeed: (rng.nextDouble() - 0.5) * 14.0,
      );
    });
  }

  void _startGhostCounter() {
    if (_ghostCounterTimer != null) return;
    _ghostCounterTimer = Timer.periodic(const Duration(milliseconds: 280), (
      t,
    ) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _ghostCounterStep =
            (_ghostCounterStep + 1) % _ghostCounterFrames.length;
      });
    });
  }

  void _spawnConfetti() {
    final cs = Theme.of(context).colorScheme;
    final rng = math.Random();
    final colors = [
      cs.primary,
      cs.tertiary,
      cs.secondary,
      cs.primaryContainer,
      cs.tertiaryContainer,
    ];
    _particles = List.generate(14, (_) {
      return _Particle(
        angle: rng.nextDouble() * 2 * math.pi,
        speed: 100.0 + rng.nextDouble() * 240.0,
        color: colors[rng.nextInt(colors.length)],
        size: 5.0 + rng.nextDouble() * 9.0,
        rotationSpeed: (rng.nextDouble() - 0.5) * 10.0,
      );
    });
  }

  // ---- accept ---------------------------------------------------------

  Future<void> _handleAccepted(Contributor dropped) async {
    if (dropped.name != _current.name) return;

    if (_isLast) {
      await _triggerKinvshGlitch();
      return;
    }

    HapticFeedback.mediumImpact();

    _progressAnim = Tween<double>(
      begin: _currentIndex / _credits.length,
      end: (_currentIndex + 1) / _credits.length,
    ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
    _progressCtrl.forward(from: 0);

    _spawnConfetti();
    setState(() {
      _showConfetti = true;
      _showFloat = true;
    });
    _confettiCtrl.forward(from: 0);
    _floatCtrl.forward(from: 0);

    _pulseCtrl.forward(from: 0).then((_) {
      if (mounted) _pulseCtrl.reverse();
    });

    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    // SURPRISE A — chen boomerang.
    if (_currentIndex == 0 && _chenBoomerangArmed) {
      _chenBoomerangArmed = false;
      setState(() => _chenBoomerangActive = true);
      HapticFeedback.lightImpact();
      _progressAnim = Tween<double>(
        begin: 1 / _credits.length,
        end: 0,
      ).animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
      _progressCtrl.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() => _chenBoomerangActive = false);
      return;
    }

    setState(() => _currentIndex++);
  }

  // ---- kinvsh dramatic exit -------------------------------------------

  Future<void> _triggerKinvshGlitch() async {
    setState(() {
      _glitching = true;
      _glitchStep = 0;
    });
    for (int i = 1; i <= 4; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _glitchStep = i);
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 450));
    await globalState.appController.handleExit();
  }

  // ---- build ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_glitching) return _KinvshGlitchScreen(step: _glitchStep);

    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final msgs = _isLast ? _kinvshPings : _pingMessages;
    final pingMsg = msgs[_pingIndex % msgs.length];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'File Transfer',
          style: TextStyle(fontFamily: 'Onest'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // header — counter cycles to nonsense when kinvsh hovers
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          transitionBuilder: (c, a) =>
                              FadeTransition(opacity: a, child: c),
                          child: Text(
                            _ghostCounterStep > 0
                                ? 'Перенеси ${_ghostCounterFrames[_ghostCounterStep]}'
                                : 'Перенеси ${_currentIndex + 1} из ${_credits.length}',
                            key: ValueKey(
                              _ghostCounterStep > 0
                                  ? 'ghost-$_ghostCounterStep'
                                  : 'real-$_currentIndex',
                            ),
                            style: textTheme.titleMedium?.copyWith(
                              fontFamily: 'Onest',
                              color: _ghostCounterStep > 0 ? cs.error : null,
                              fontFeatures: _ghostCounterStep > 0
                                  ? const [FontFeature.tabularFigures()]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      if (_isLast)
                        Text(
                          '⚠ последний',
                          style: textTheme.labelSmall?.copyWith(
                            fontFamily: 'Onest',
                            color: cs.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Тащи карточку из «contributors/» в «shipped/».',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // progress bar (animated)
                  AnimatedBuilder(
                    animation: _progressCtrl,
                    builder: (_, __) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressAnim.value,
                        minHeight: 4,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // chen boomerang banner
                  if (_chenBoomerangActive)
                    _buildBoomerangBanner(cs, textTheme),

                  _FolderHeader(
                    label: 'contributors/',
                    icon: Icons.folder_outlined,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),

                  // draggable card + ping bubble
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _ContributorDraggable(
                        person: _current,
                        isKinvsh: _isLast,
                        onDragStarted: _onDragStarted,
                        onDragEnd: (_) => _onDragEnded(),
                        onDragCompleted: _onDragEnded,
                        onDraggableCanceled: _onDragCanceled,
                      ),
                      if (_isDragging)
                        Positioned(
                          top: -36,
                          right: 0,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.3),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Container(
                              key: ValueKey(pingMsg),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _isLast
                                    ? cs.errorContainer
                                    : cs.secondaryContainer,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                pingMsg,
                                style: textTheme.labelSmall?.copyWith(
                                  fontFamily: 'Onest',
                                  fontWeight: FontWeight.w700,
                                  color: _isLast
                                      ? cs.onErrorContainer
                                      : cs.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  _FolderHeader(
                    label: 'shipped/',
                    icon: Icons.folder_rounded,
                    color: _isLast ? cs.error : cs.primary,
                  ),
                  const SizedBox(height: 12),

                  // wandering + shrinking drop zone
                  //
                  // NOTE: we CANNOT animate width/height from `double.infinity`
                  // to a finite number — Flutter can't interpolate between
                  // unbounded and bounded constraints (box.dart:495 assert).
                  // Instead we use LayoutBuilder to resolve the actual
                  // parent size, then AnimatedContainer between two FINITE
                  // numbers: the full available size when idle, 220 square
                  // while dragging.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Guard against unbounded parents on the first
                        // layout pass — AnimatedContainer cannot lerp
                        // between a finite value and double.infinity.
                        final fullW = constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : 360.0;
                        final fullH = constraints.maxHeight.isFinite
                            ? constraints.maxHeight
                            : 480.0;
                        const targetSize = 220.0;
                        return Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            width: _isDragging ? targetSize : fullW,
                            height: _isDragging ? targetSize : fullH,
                            child: AnimatedBuilder(
                              animation: _wanderCtrl,
                              builder: (context, child) {
                                final t = _wanderCtrl.value * 2 * math.pi;
                                final amp = _isDragging ? 1.6 : 1.0;
                                final freq = _isDragging ? 1.8 : 1.0;
                                final dx =
                                    55.0 * amp * math.sin(t * 0.7 * freq);
                                final dy =
                                    32.0 * amp * math.sin(t * 1.3 * freq + 1.0);
                                return Transform.translate(
                                  offset: Offset(dx, dy),
                                  child: child,
                                );
                              },
                              child: AnimatedBuilder(
                                animation: _pulseScale,
                                builder: (context, child) => Transform.scale(
                                  scale: _pulseScale.value,
                                  child: child,
                                ),
                                child: _buildDropZone(cs, textTheme),
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

            // shard burst overlay
            if (_showShards)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _shardCtrl,
                      builder: (_, __) => CustomPaint(
                        painter: _ShardPainter(
                          particles: _shardParticles,
                          progress: _shardCtrl.value,
                          origin: _shardOrigin,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoomerangBanner(ColorScheme cs, TextTheme tt) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.error.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'не так быстро.',
                    style: tt.bodyLarge?.copyWith(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w700,
                      color: cs.error,
                    ),
                  ),
                  Text(
                    'chen08209 вернулся. попробуй ещё раз.',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDropZone(ColorScheme cs, TextTheme tt) => Stack(
        children: [
          DragTarget<Contributor>(
            onWillAcceptWithDetails: (d) {
              if (_isLast && d.data.name == _current.name) {
                _startGhostCounter();
              }
              return d.data.name == _current.name;
            },
            onLeave: (_) {
              _ghostCounterTimer?.cancel();
              _ghostCounterTimer = null;
              if (mounted) setState(() => _ghostCounterStep = 0);
            },
            onAcceptWithDetails: (d) => _handleAccepted(d.data),
            builder: (_, candidate, __) {
              final hovering = candidate.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: hovering
                      ? (_isLast
                          ? cs.errorContainer.withValues(alpha: 0.45)
                          : cs.primaryContainer.withValues(alpha: 0.45))
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hovering
                        ? (_isLast ? cs.error : cs.primary)
                        : (_isLast
                            ? cs.error.withValues(alpha: 0.35)
                            : cs.outlineVariant),
                    width: hovering ? 2 : (_isLast ? 1.5 : 1),
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hovering
                            ? (_isLast ? 'не делай этого…' : 'Отпусти.')
                            : (_isLast ? 'ты уверен?' : 'Сюда.'),
                        style: tt.bodyLarge?.copyWith(
                          fontFamily: 'Onest',
                          color: hovering
                              ? (_isLast ? cs.error : cs.primary)
                              : (_isLast ? cs.error : cs.onSurfaceVariant),
                        ),
                      ),
                      if (_showFloat)
                        AnimatedBuilder(
                          animation: _floatCtrl,
                          builder: (_, __) => Transform.translate(
                            offset: Offset(0, _floatDy.value),
                            child: Opacity(
                              opacity: _floatOpacity.value,
                              child: Text(
                                '+1 shipped',
                                style: tt.labelSmall?.copyWith(
                                  fontFamily: 'Onest',
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_showConfetti)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _confettiCtrl,
                    builder: (_, __) => CustomPaint(
                      painter: _ConfettiPainter(
                        particles: _particles,
                        progress: _confettiCtrl.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

// ======================================================================
// Particle data + painters
// ======================================================================

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.rotationSpeed,
  });

  final double angle;
  final double speed; // px/s
  final Color color;
  final double size;
  final double rotationSpeed; // rad/s

  static const _totalSecs = 0.7;
  static const _gravity = 380.0;

  Offset positionAt(double t, Offset origin) {
    final s = t * _totalSecs;
    return Offset(
      origin.dx + math.cos(angle) * speed * s,
      origin.dy + math.sin(angle) * speed * s + 0.5 * _gravity * s * s,
    );
  }

  double alphaAt(double t) =>
      (1.0 - math.pow(t, 0.55).toDouble()).clamp(0.0, 1.0);

  double rotationAt(double t) => angle + rotationSpeed * t * _totalSecs;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});
  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final alpha = p.alphaAt(progress);
      if (alpha <= 0) continue;
      paint.color = p.color.withValues(alpha: alpha);
      final pos = p.positionAt(progress, origin);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotationAt(progress));
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _ShardPainter extends CustomPainter {
  _ShardPainter({
    required this.particles,
    required this.progress,
    required this.origin,
  });
  final List<_Particle> particles;
  final double progress;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final alpha = p.alphaAt(progress);
      if (alpha <= 0) continue;
      paint.color = p.color.withValues(alpha: alpha);
      final pos = p.positionAt(progress, origin);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.rotationAt(progress));
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size * 1.6,
          height: p.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ShardPainter old) =>
      old.progress != progress || old.origin != origin;
}

// ======================================================================
// Kinvsh dramatic glitch screen
// ======================================================================

class _KinvshGlitchScreen extends StatelessWidget {
  const _KinvshGlitchScreen({required this.step});
  final int step; // 0=black, odd=red, ≥4=black + terminal trace

  static const _errorLines = [
    'ERROR: connection refused (errno 111)',
    'система ответила отказом',
    'соединение разорвано',
    'попытка восстановления — неудачно',
    'retry 1/3… timeout',
    'retry 2/3… timeout',
    'retry 3/3… FATAL',
    'процесс будет завершён',
    'PID 1337 → SIGKILL',
    'kernel panic: unexpected contributor',
    'fatal: cannot ship kinvsh',
  ];

  @override
  Widget build(BuildContext context) {
    final isRed = step.isOdd;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: isRed ? cs.error : Colors.black,
      body: SafeArea(
        child: (step < 4 || isRed)
            ? const SizedBox.expand()
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '█ КРИТИЧЕСКАЯ ОШИБКА █',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: cs.error,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final line in _errorLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          '> $line',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xCCFFFFFF),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      '…',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0x55FFFFFF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ======================================================================
// Folder header + draggable card
// ======================================================================

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
  Widget build(BuildContext context) => Row(
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

class _ContributorDraggable extends StatelessWidget {
  const _ContributorDraggable({
    required this.person,
    required this.isKinvsh,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDragCompleted,
    required this.onDraggableCanceled,
  });

  final Contributor person;
  final bool isKinvsh;
  final VoidCallback onDragStarted;
  final void Function(DraggableDetails) onDragEnd;
  final VoidCallback onDragCompleted;
  final DraggableCanceledCallback onDraggableCanceled;

  Widget _buildCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: isKinvsh
          ? cs.errorContainer.withValues(alpha: 0.25)
          : cs.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isKinvsh ? cs.error : cs.outlineVariant,
            width: isKinvsh ? 1.5 : 1,
          ),
          boxShadow: isKinvsh
              ? [
                  BoxShadow(
                    color: cs.error.withValues(alpha: 0.30),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              foregroundImage: AssetImage(person.avatar),
              backgroundColor:
                  isKinvsh ? cs.errorContainer : cs.primaryContainer,
              child: Text(
                person.name[0].toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Onest',
                  color: isKinvsh ? cs.onErrorContainer : cs.onPrimaryContainer,
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
                    style: tt.bodyLarge?.copyWith(
                      fontFamily: 'Onest',
                      fontWeight: FontWeight.w600,
                      color: isKinvsh ? cs.error : null,
                    ),
                  ),
                  Text(
                    person.role,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.drag_indicator_rounded,
              color: isKinvsh ? cs.error : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);
    return Draggable<Contributor>(
      data: person,
      onDragStarted: onDragStarted,
      onDragEnd: onDragEnd,
      onDragCompleted: onDragCompleted,
      onDraggableCanceled: onDraggableCanceled,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 32,
          child: Transform.rotate(
            angle: isKinvsh ? -0.07 : -0.03,
            child: _buildCard(context),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: card),
      child: card,
    );
  }
}
