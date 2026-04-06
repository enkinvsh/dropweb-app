import 'dart:ui' as ui;

import 'package:dropweb/common/lumina.dart';
import 'package:flutter/material.dart';

class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: CustomPaint(
          painter: _MeshPainter(),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-left: green glow
    final paint1 = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        size.longestSide * 0.5,
        [Lumina.glowPrimary.withValues(alpha: 0.10), Colors.transparent],
        [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint1);

    // Top-right: light green glow
    final paint2 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width, 0),
        size.longestSide * 0.5,
        [Lumina.glowSecondary.withValues(alpha: 0.08), Colors.transparent],
        [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint2);

    // Bottom-right: blue glow
    final paint3 = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width, size.height),
        size.longestSide * 0.5,
        [Lumina.glowAccent.withValues(alpha: 0.10), Colors.transparent],
        [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint3);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
