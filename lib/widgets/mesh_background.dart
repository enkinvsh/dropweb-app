import 'package:flutter/material.dart';

class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return const SizedBox.shrink();
    }
    final primary = theme.colorScheme.primary;
    final tertiary = theme.colorScheme.tertiary;

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.2,
                  colors: [
                    primary.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.2,
                  colors: [
                    primary.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  radius: 1.2,
                  colors: [
                    tertiary.withValues(alpha: 0.18),
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
