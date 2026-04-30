import 'package:dropweb/common/lumina.dart';
import 'package:flutter/material.dart';

/// Collapsed-by-default "Параметры соединения" accordion.
///
/// Hides itself when [lines] is empty — idle / connecting / error states
/// have nothing to show. Surface uses Lumina tokens so it sits in the
/// same visual ladder as the hero card.
class ConnectionDetailsPanel extends StatelessWidget {
  const ConnectionDetailsPanel({super.key, required this.lines});

  /// Plain-language lines. Order matters — first is most informative.
  /// Empty list hides the panel entirely.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final decoration = isDark
        ? Lumina.glass(radius: Lumina.radiusMd)
        : BoxDecoration(
            color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(Lumina.radiusMd),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: Lumina.glassShadow,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        decoration: decoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Lumina.radiusMd),
          child: Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(
                'Параметры',
                style: theme.textTheme.titleSmall,
              ),
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
