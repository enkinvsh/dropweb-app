import 'package:flutter/material.dart';

/// Faint footer line at the bottom of the VK Calls page.
///
/// Phase 1: a single neutral hint line. Phase 3 wires real build
/// metadata (version + build + session id) with long-press to copy.
class FooterDiagnostics extends StatelessWidget {
  const FooterDiagnostics({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Text(
        line,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
