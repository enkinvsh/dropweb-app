import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ServiceInfoWidget extends ConsumerStatefulWidget {
  const ServiceInfoWidget({super.key});

  @override
  ConsumerState<ServiceInfoWidget> createState() => _ServiceInfoWidgetState();
}

class _ServiceInfoWidgetState extends ConsumerState<ServiceInfoWidget> {
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

  String? _decodeBase64IfNeeded(String? value) {
    if (value == null || value.isEmpty) return value;

    try {
      final decoded = utf8.decode(base64.decode(value));
      return decoded;
    } catch (e) {
      return value;
    }
  }

  String? _decodeAnnounce(String? encodedText) {
    if (encodedText == null || encodedText.isEmpty) return null;
    var textToDecode = encodedText;
    if (encodedText.startsWith('base64:')) {
      textToDecode = encodedText.substring(7);
    }
    try {
      final normalized = base64.normalize(textToDecode);
      return utf8.decode(base64.decode(normalized));
    } catch (e) {
      return encodedText;
    }
  }

  Widget _buildLogo(BuildContext context, String? logoUrl) {
    const logoSize = 44.0;
    const borderRadius = 8.0;

    if (logoUrl == null || logoUrl.isEmpty) {
      return HugeIcon(
        icon: HugeIcons.strokeRoundedMail01,
        size: logoSize,
        color: context.colorScheme.primary,
      );
    }

    final isSvg = logoUrl.toLowerCase().endsWith('.svg');

    Widget logoWidget;
    if (isSvg) {
      logoWidget = SvgPicture.network(
        logoUrl,
        width: logoSize,
        height: logoSize,
        placeholderBuilder: (context) => HugeIcon(
          icon: HugeIcons.strokeRoundedMail01,
          size: logoSize,
          color: context.colorScheme.primary,
        ),
      );
    } else {
      logoWidget = CachedNetworkImage(
        imageUrl: logoUrl,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.cover,
        placeholder: (context, url) => HugeIcon(
          icon: HugeIcons.strokeRoundedMail01,
          size: logoSize,
          color: context.colorScheme.primary,
        ),
        errorWidget: (context, url, error) => HugeIcon(
          icon: HugeIcons.strokeRoundedMail01,
          size: logoSize,
          color: context.colorScheme.primary,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: logoWidget,
    );
  }

  List<InlineSpan> _buildAnnounceSpans(BuildContext context, String text) {
    final urlPattern = RegExp(r'https?://[^\s]+', caseSensitive: false);
    final spans = <InlineSpan>[];
    var lastIndex = 0;
    final style = context.textTheme.bodyMedium?.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );

    for (final match in urlPattern.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => globalState.openUrl(url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: style?.copyWith(color: context.colorScheme.primary),
        recognizer: recognizer,
      ));
      lastIndex = match.end;
    }
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);

    // Dispose previous recognizers before rebuilding spans.
    _disposeRecognizers();

    if (profile == null) {
      return const SizedBox.shrink();
    }

    final headers = profile.providerHeaders;
    final serviceName = _decodeBase64IfNeeded(headers['flclashx-servicename']);
    final supportUrl = headers['support-url'];
    final logoUrl = _decodeBase64IfNeeded(headers['flclashx-servicelogo']);
    final announceText = _decodeAnnounce(headers['announce']);

    if (serviceName == null || serviceName.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasAnnounce = announceText != null && announceText.isNotEmpty;

    return CommonCard(
      onPressed: (supportUrl != null && supportUrl.isNotEmpty)
          ? () {
              globalState.openUrl(supportUrl);
            }
          : null,
      child: Padding(
        padding: baseInfoEdgeInsets.copyWith(top: 8, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLogo(context, logoUrl),
                      const SizedBox(width: 10),
                      Flexible(
                        child: EmojiText(
                          serviceName,
                          style: context.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (supportUrl != null && supportUrl.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCustomerSupport,
                      size: 28,
                      color: context.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ],
            ),
            if (hasAnnounce) ...[
              const SizedBox(height: 8),
              Divider(
                  height: 1,
                  color: context.colorScheme.outlineVariant
                      .withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: _buildAnnounceSpans(context, announceText),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
