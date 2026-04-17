import 'dart:math' as math;
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/pages/home.dart' show connectButtonCenter;
import 'package:dropweb/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fullscreen expanding rings from the connect button's exact screen position.
///
/// Reads [connectButtonCenter] (set by _ConnectCircle via GlobalKey).
/// 4 rings, 8s cycle, expand to cover the full screen diagonal.
class MagicRingsOverlay extends ConsumerStatefulWidget {
  const MagicRingsOverlay({super.key});

  @override
  ConsumerState<MagicRingsOverlay> createState() => _MagicRingsOverlayState();
}

class _MagicRingsOverlayState extends ConsumerState<MagicRingsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(runTimeProvider) != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Only show on dashboard — rings must not leak into Settings/other pages.
    final isOnDashboard = ref.watch(isCurrentPageProvider(PageLabel.dashboard));
    final visible = isConnected && isDark && isOnDashboard;

    if (visible && !_controller.isAnimating) _controller.repeat();

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      onEnd: () {
        if (!visible && _controller.isAnimating) {
          _controller.stop();
          _controller.reset();
        }
      },
      child: IgnorePointer(
        child: RepaintBoundary(
          child: ValueListenableBuilder<Offset?>(
            valueListenable: connectButtonCenter,
            builder: (_, btnCenter, __) {
              if (btnCenter == null) return const SizedBox.shrink();
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final box = context.findRenderObject() as RenderBox?;
                  final localCenter =
                      box != null ? box.globalToLocal(btnCenter) : btnCenter;
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _FullscreenRingsPainter(
                      progress: _controller.value,
                      color: Theme.of(context).colorScheme.primary,
                      center: localCenter,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FullscreenRingsPainter extends CustomPainter {
  _FullscreenRingsPainter({
    required this.progress,
    required this.color,
    required this.center,
  });

  final double progress;
  final Color color;
  final Offset center;

  static const _ringCount = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height);

    for (int i = 0; i < _ringCount; i++) {
      final phase = (progress + i / _ringCount) % 1.0;
      final radius = phase * maxRadius;
      final fade = 1.0 - phase;
      final alpha = fade * fade * 0.15;
      if (alpha < 0.003) continue;
      final strokeWidth = 0.8 * (1.0 - phase * 0.5);
      if (strokeWidth < 0.1) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_FullscreenRingsPainter old) =>
      old.progress != progress || old.center != center;
}
