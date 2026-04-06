import 'package:dropweb/common/lumina.dart';
import 'package:flutter/material.dart';

/// Mesh gradient background built from layered radial gradients.
///
/// Uses a simple [DecoratedBox] stack instead of [CustomPaint]+[ImageFiltered].
/// This avoids two critical Flutter rendering pitfalls:
///   1. `Size.infinite` inside `ImageFiltered` can clip to zero.
///   2. `ImageFiltered` blur on unbounded paint areas may produce no output.
///
/// The radial gradients are intentionally large (radius = 120% of shortest
/// side) so that they bleed softly into each other, producing a mesh-like
/// effect without needing an explicit blur pass.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    // Three radial gradient layers painted on top of each other.
    // Each one is a DecoratedBox that fills the available space.
    return RepaintBoundary(
      child: Stack(
        children: [
          // Layer 1 — top-left green glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: [
                    Lumina.glowPrimary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Layer 2 — top-right light-green glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [
                    Lumina.glowSecondary.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          // Layer 3 — bottom-right blue glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  radius: 1.2,
                  colors: [
                    Lumina.glowAccent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
