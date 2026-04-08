import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Animated vertical light pillars that drift slowly upward.
///
/// Renders four translucent vertical bars with a horizontal fade-out gradient.
/// Used as an ambient background effect on the dashboard screen.
class LightPillar extends StatefulWidget {
  const LightPillar({super.key});

  @override
  State<LightPillar> createState() => _LightPillarState();
}

class _LightPillarState extends State<LightPillar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          // Let the CustomPaint fill whatever constraints it receives
          // from Positioned.fill — never use Size.infinite.
          painter: _PillarPainter(_controller.value),
        ),
      ),
    );
  }
}

class _PillarPainter extends CustomPainter {
  _PillarPainter(this.progress);

  final double progress;

  // Define pillars: (xFraction, width, opacity, speed)
  // Reduced from 4 → 2 for mid-range Android perf. Kept the two widest/most
  // visible pillars; visual loss is minor, GPU work is halved.
  static const _pillars = [
    (0.4, 100.0, 0.08, 0.7),
    (0.85, 80.0, 0.07, 0.9),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return; // guard against zero-size

    for (final (xFrac, width, opacity, speed) in _pillars) {
      final x = size.width * xFrac;
      // Slow vertical drift — each pillar drifts at different speed
      final yOffset =
          (progress * speed * size.height * 0.3) % (size.height * 0.3);

      final rect = Rect.fromLTWH(
          x - width / 2, -yOffset, width, size.height + size.height * 0.3);

      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.right, rect.top),
          [
            Colors.transparent,
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: opacity),
            Colors.transparent,
          ],
          [0.0, 0.3, 0.7, 1.0],
        );

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_PillarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
