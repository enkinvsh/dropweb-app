import 'package:dropweb/common/lumina.dart';
import 'package:flutter/material.dart';

/// Direction A "Тихий оператор" primary call-to-action.
///
/// Calm, banking-grade, single full-width button with a single line of
/// supporting text below. No icons-as-hero, no glow, no cyberpunk motifs.
/// The card is the only place a user activates VK Звонки на странице
/// `VK Звонки`; it replaces the settings-style switch row that lived in
/// Phase 1.
///
/// Tonality knobs:
/// * [tonal] — render the button with [FilledButton.tonal] styling. Use
///   for the "active / отключить" state where the action is destructive
///   in spirit but should remain visible and easy to hit.
/// * [showProgress] — paint a small inline progress indicator next to
///   the label while the activation is in flight.
class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.label,
    required this.supportingText,
    required this.onPressed,
    this.tonal = false,
    this.showProgress = false,
  });

  /// Button label. Visible — must remain Google Play and Russian-law
  /// safe. Examples: "Войти и включить", "Включить режим стабильности",
  /// "Подключаем...", "Отключить режим".
  final String label;

  /// Supporting body text rendered under the button. One short Russian
  /// sentence describing the current state.
  final String supportingText;

  /// Tap handler. Pass `null` to render the CTA as disabled — used while
  /// activation is in flight or whenever the toggle should debounce.
  final VoidCallback? onPressed;

  /// When `true`, render with [FilledButton.tonal] instead of the
  /// default [FilledButton] surface. Keeps the action visible while
  /// signalling that it is the calmer of the two state branches
  /// (e.g. "уже активно — отключить").
  final bool tonal;

  /// When `true`, paint a 16x16 progress indicator left of the label.
  /// Visual only — does NOT change the disabled semantics. Pair with
  /// `onPressed: null` while a request is in flight.
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showProgress) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tonal
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    final style = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Lumina.radiusMd),
      ),
      textStyle: theme.textTheme.titleMedium,
    );

    final button = tonal
        ? FilledButton.tonal(
            onPressed: onPressed,
            style: style,
            child: buttonChild,
          )
        : FilledButton(
            onPressed: onPressed,
            style: style,
            child: buttonChild,
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: 10),
          Text(
            supportingText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
