import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = globalState.appState.runTime != null;

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _breatheAnimation = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _breatheController, curve: Lumina.luminaCurve),
    );

    if (isStart) {
      _breatheController.repeat(reverse: true);
    }

    ref.listenManual(
      runTimeProvider.select((state) => state != null),
      (prev, next) {
        if (next != isStart) {
          setState(() {
            isStart = next;
          });
          if (next) {
            _breatheController.repeat(reverse: true);
          } else {
            _breatheController.stop();
            _breatheController.reset();
          }
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void handleSwitchStart() {
    isStart = !isStart;
    setState(() {});
    debouncer.call(
      FunctionTag.updateStatus,
      () {
        globalState.appController.updateStatus(isStart);
      },
      duration: commonDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.isInit || !state.hasProfile) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

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
        onTap: handleSwitchStart,
        child: Center(
          child: AnimatedBuilder(
            animation: _breatheAnimation,
            builder: (_, __) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Bioluminescent breathe glow when active
                  boxShadow: isStart
                      ? [
                          BoxShadow(
                            color: colorScheme.primary
                                .withValues(alpha: _breatheAnimation.value),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  isStart
                      ? Icons.stop_rounded
                      : Icons.power_settings_new_rounded,
                  size: 26,
                  color: isStart
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
