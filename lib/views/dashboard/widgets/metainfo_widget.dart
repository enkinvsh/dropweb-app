import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/views/subscription.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

class MetainfoWidget extends ConsumerStatefulWidget {
  const MetainfoWidget({super.key});

  @override
  ConsumerState<MetainfoWidget> createState() => _MetainfoWidgetState();
}

class _MetainfoWidgetState extends ConsumerState<MetainfoWidget> {
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

  String _getDaysDeclension(int days) {
    if (days % 100 >= 11 && days % 100 <= 19) {
      return appLocalizations.days;
    }
    switch (days % 10) {
      case 1:
        return appLocalizations.day;
      case 2:
      case 3:
      case 4:
        return appLocalizations.daysGenitive;
      default:
        return appLocalizations.days;
    }
  }

  String _getHoursDeclension(int hours) {
    if (hours % 100 >= 11 && hours % 100 <= 19) {
      return appLocalizations.hoursGenitive;
    }
    switch (hours % 10) {
      case 1:
        return appLocalizations.hour;
      case 2:
      case 3:
      case 4:
        return appLocalizations.hoursPlural;
      default:
        return appLocalizations.hoursGenitive;
    }
  }

  String _getRemainingDeclension(int value) {
    if (value % 100 != 11 && value % 10 == 1) {
      return appLocalizations.remainingSingular;
    }
    return appLocalizations.remainingPlural;
  }

  String? _decodeBase64IfNeeded(String? value) {
    if (value == null || value.isEmpty) return value;
    try {
      return utf8.decode(base64.decode(value));
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

  Widget _buildLogo(BuildContext context, String logoUrl) {
    const logoSize = 36.0;
    const borderRadius = 8.0;
    const placeholder = SizedBox(width: logoSize, height: logoSize);

    final isSvg = logoUrl.toLowerCase().endsWith('.svg');

    Widget logoWidget;
    if (isSvg) {
      logoWidget = SvgPicture.network(
        logoUrl,
        width: logoSize,
        height: logoSize,
        placeholderBuilder: (_) => placeholder,
      );
    } else {
      logoWidget = CachedNetworkImage(
        imageUrl: logoUrl,
        width: logoSize,
        height: logoSize,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
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
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
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
        style: style?.copyWith(color: theme.colorScheme.primary),
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
    final allProfiles = ref.watch(profilesProvider);
    final currentProfile = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    // Dispose previous recognizers before rebuilding spans to avoid leaks
    // (announce text can change when profile headers update).
    _disposeRecognizers();

    if (allProfiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final subscriptionInfo = currentProfile?.subscriptionInfo;

    if (currentProfile == null || subscriptionInfo == null) {
      return const SizedBox.shrink();
    }

    final isUnlimitedTraffic = subscriptionInfo.total == 0;
    final isPerpetual = subscriptionInfo.expire == 0;

    final headers = currentProfile.providerHeaders;
    final supportUrl = headers['support-url'];
    final serviceName = _decodeBase64IfNeeded(headers['dropweb-servicename']);
    final logoUrl = _decodeBase64IfNeeded(headers['dropweb-servicelogo']);
    final announceText = _decodeAnnounce(headers['announce']);

    final hasLogo = logoUrl != null && logoUrl.isNotEmpty;
    final hasServiceName = serviceName != null && serviceName.isNotEmpty;
    final hasAnnounce = announceText != null && announceText.isNotEmpty;

    final titleText =
        hasServiceName ? serviceName : appLocalizations.subscription;

    var timeLeftValue = '';
    var timeLeftUnit = '';
    var remainingText = '';
    var showTimeLeft = false;

    if (!isPerpetual) {
      final expireDateTime =
          DateTime.fromMillisecondsSinceEpoch(subscriptionInfo.expire * 1000);
      final difference = expireDateTime.difference(DateTime.now());
      final days = difference.inDays;

      if (days >= 0 && days <= 3) {
        showTimeLeft = true;
        if (days > 0) {
          timeLeftValue = days.toString();
          timeLeftUnit = _getDaysDeclension(days);
          remainingText = _getRemainingDeclension(days);
        } else {
          final hours = difference.inHours;
          if (hours >= 0) {
            timeLeftValue = hours.toString();
            timeLeftUnit = _getHoursDeclension(hours);
            remainingText = _getRemainingDeclension(hours);
          } else {
            showTimeLeft = false;
          }
        }
      }
    }

    return CommonCard(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SubscriptionPage(),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasLogo) ...[
                          _buildLogo(context, logoUrl),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: EmojiText(
                            titleText,
                            style: theme.textTheme.headlineSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (supportUrl != null && supportUrl.isNotEmpty)
                          IconButton(
                            icon: HugeIcon(
                              icon: supportUrl.toLowerCase().contains('t.me')
                                  ? HugeIcons.strokeRoundedTelegram
                                  : HugeIcons.strokeRoundedLinkSquare01,
                              size: 34,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () {
                              globalState.openUrl(supportUrl);
                            },
                          ),
                        IconButton(
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedRefresh,
                            size: 34,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () {
                            globalState.appController
                                .updateProfile(currentProfile);
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!isUnlimitedTraffic)
                      Builder(builder: (context) {
                        final totalTraffic =
                            TrafficValue(value: subscriptionInfo.total);
                        final usedTrafficValue =
                            subscriptionInfo.upload + subscriptionInfo.download;
                        final usedTraffic =
                            TrafficValue(value: usedTrafficValue);

                        var progress = 0.0;
                        if (subscriptionInfo.total > 0) {
                          progress = usedTrafficValue / subscriptionInfo.total;
                        }
                        progress = progress.clamp(0.0, 1.0);

                        Color progressColor = Colors.green;
                        if (progress > 0.9) {
                          progressColor = Colors.red;
                        } else if (progress > 0.7) {
                          progressColor = Colors.orange;
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${appLocalizations.traffic} ${usedTraffic.showValue} ${usedTraffic.showUnit} / ${totalTraffic.showValue} ${totalTraffic.showUnit}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    progressColor),
                              ),
                            ),
                          ],
                        );
                      })
                    else
                      Text(
                        appLocalizations.trafficUnlimited,
                        style: theme.textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 12),
                    Text(
                      isPerpetual
                          ? appLocalizations.subscriptionEternal
                          : '${appLocalizations.expiresOn} ${DateFormat('dd.MM.yyyy').format(DateTime.fromMillisecondsSinceEpoch(subscriptionInfo.expire * 1000))}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (hasAnnounce) ...[
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          children: _buildAnnounceSpans(context, announceText),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showTimeLeft) ...[
                const VerticalDivider(width: 32),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      remainingText,
                      style: theme.textTheme.bodySmall,
                    ),
                    FittedBox(
                      fit: BoxFit.contain,
                      child: Text(
                        timeLeftValue,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Text(
                      timeLeftUnit,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
