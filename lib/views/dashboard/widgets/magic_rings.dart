import 'dart:math' as math;
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
      duration: const Duration(milliseconds: 8000),
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

    if (isConnected) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
        _controller.reset();
      }
    }

    if (!isConnected) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: ValueListenableBuilder<Offset?>(
          valueListenable: connectButtonCenter,
          builder: (_, btnCenter, __) {
            if (btnCenter == null) return const SizedBox.shrink();
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                // Convert screen-space button center to local paint coords
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

  static const _ringCount = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height);

    for (int i = 0; i < _ringCount; i++) {
      final phase = (progress + i / _ringCount) % 1.0;
      final radius = phase * maxRadius;
      final alpha = (1.0 - phase * phase) * 0.12;
      if (alpha < 0.005) continue;
      final strokeWidth = 1.5 * (1.0 - phase);
      if (strokeWidth < 0.2) continue;

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
