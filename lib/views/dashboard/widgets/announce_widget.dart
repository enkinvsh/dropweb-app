import 'dart:convert';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnounceWidget extends ConsumerStatefulWidget {
  const AnnounceWidget({super.key});

  @override
  ConsumerState<AnnounceWidget> createState() => _AnnounceWidgetState();
}

class _AnnounceWidgetState extends ConsumerState<AnnounceWidget> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _buildTextSpans(BuildContext context, String text) {
    final urlPattern = RegExp(
      r'https?://[^\s]+',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var lastIndex = 0;

    for (final match in urlPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: Theme.of(context).textTheme.bodyLarge,
        ));
      }

      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => globalState.openUrl(url);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: url,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
        recognizer: recognizer,
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: Theme.of(context).textTheme.bodyLarge,
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    if (profile == null) {
      return const SizedBox.shrink();
    }

    final encodedText = profile.providerHeaders['announce'];
    String? announceText;

    if (encodedText != null && encodedText.isNotEmpty) {
      var textToDecode = encodedText;
      if (encodedText.startsWith('base64:')) {
        textToDecode = encodedText.substring(7);
      }
      try {
        final normalized = base64.normalize(textToDecode);
        announceText = utf8.decode(base64.decode(normalized));
      } catch (_) {
        announceText = encodedText;
      }
    }

    if (announceText == null || announceText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Rebuild recognizers each build — text can change when profile updates.
    // Dispose previous recognizers to avoid leaking them on every rebuild.
    _disposeRecognizers();

    return CommonCard(
      onPressed: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Align(
          alignment: Alignment.topLeft,
          child: RichText(
            text: TextSpan(
              children: _buildTextSpans(context, announceText),
            ),
          ),
        ),
      ),
    );
  }
}
