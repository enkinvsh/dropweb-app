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
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool isStart = false;

  @override
  void initState() {
    super.initState();
    isStart = globalState.appState.runTime != null;

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOut,
      ),
    );

    ref.listenManual(
      runTimeProvider.select((state) => state != null),
      (prev, next) {
        if (next != isStart) {
          setState(() {
            isStart = next;
          });
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
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

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
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
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: handleSwitchStart,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: isStart ? colorScheme.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isStart ? Icons.stop_rounded : Icons.power_settings_new_rounded,
                size: 28,
                color: isStart
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
