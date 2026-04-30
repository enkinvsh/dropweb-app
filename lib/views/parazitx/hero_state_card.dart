import 'package:dropweb/common/lumina.dart';
import 'package:flutter/material.dart';

import 'vk_calls_state.dart';

/// VK Calls hero state card. Lumina-native glass surface, single status
/// dot, one short Russian sentence.
///
/// Intentionally no `AnimatedSwitcher` around the headline/detail Text
/// children: the keyed text rebuilds combined with `Theme.of(context)`
/// reads inside an `OpenContainer`/`CommonScaffold` route triggered the
/// Flutter `_dependents.isEmpty` assertion during element deactivation
/// (page pop / hot reload). The card has no need for a 200ms text fade
/// in Lumina, so the safer pattern is plain Text — value changes flip
/// instantly together with the status dot color.
class HeroStateCard extends StatelessWidget {
  const HeroStateCard({
    super.key,
    required this.state,
    required this.headline,
    required this.detail,
  });

  final VkCallsState state;
  final String headline;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = state.accentColor(context);

    final decoration = isDark
        ? Lumina.glass(radius: Lumina.radiusLg)
        : BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.85,
            ),
            borderRadius: BorderRadius.circular(Lumina.radiusLg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: Lumina.glassShadow,
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: Lumina.luminaDuration,
                curve: Lumina.luminaCurve,
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
