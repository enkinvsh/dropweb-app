import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/profiles/add_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class StartButton extends ConsumerStatefulWidget {
  const StartButton({super.key});

  @override
  ConsumerState<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends ConsumerState<StartButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    // Breathing alpha restored to be visible on OLED while still gentler than
    // pre-Tier-1 values (was 0.2-0.5, Tier-1 dropped to 0.15-0.3 → invisible).
    _breatheAnimation = Tween<double>(begin: 0.25, end: 0.45).animate(
      CurvedAnimation(parent: _breatheController, curve: Lumina.luminaCurve),
    );

    final initialRunning = globalState.appState.runTime != null;
    if (initialRunning || globalState.config.currentProfileId == null) {
      _breatheController.repeat(reverse: true);
    }
  }

  void _syncBreathe({required bool running, required bool hasProfile}) {
    final shouldAnimate = running || !hasProfile;
    if (shouldAnimate && !_breatheController.isAnimating) {
      _breatheController.repeat(reverse: true);
    } else if (!shouldAnimate && _breatheController.isAnimating) {
      _breatheController.stop();
      _breatheController.reset();
    }
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void handleSwitchStart() {
    HapticFeedback.mediumImpact();
    final currentlyRunning = ref.read(runTimeProvider) != null;
    final next = !currentlyRunning;
    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(next);
      },
      duration: commonDuration,
    );
  }

  void _handleAddProfile() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 240,
          child: AddProfileView(context: context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    // Watch runTimeProvider so external VPN stops (QS tile, notification, revoke) flip the icon.
    final isStart = ref.watch(runTimeProvider) != null;
    if (!state.isInit) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final hasProfile = state.hasProfile;
    // AnimationController mutations must be post-frame — running them in build = ANR loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncBreathe(running: isStart, hasProfile: hasProfile);
    });

    return AnimatedBuilder(
      animation: _pressController,
      builder: (_, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        onTap: hasProfile ? handleSwitchStart : _handleAddProfile,
        child: Center(
          child: AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (_, __) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: (isStart && hasProfile) || !hasProfile
                      ? [
                          BoxShadow(
                            color: colorScheme.primary
                                .withValues(alpha: _breatheAnimation.value),
                            blurRadius: !hasProfile ? 12 : 8,
                            spreadRadius: !hasProfile ? 2 : 1,
                          ),
                        ]
                      : [],
                ),
                child: HugeIcon(
                  icon: !hasProfile
                      ? HugeIcons.strokeRoundedAdd01
                      : isStart
                          ? HugeIcons.strokeRoundedStop
                          : HugeIcons.strokeRoundedPlugSocket,
                  size: 26,
                  color: !hasProfile
                      ? colorScheme.primary
                      : isStart
                          ? colorScheme.primary
                          : Colors.white.withValues(alpha: 0.5),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
