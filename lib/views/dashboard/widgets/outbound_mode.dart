import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/providers/config.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

/// Mode.rule  = Smart  (auto-select via url-test)
/// Mode.direct = Rules  (manual select, repurposed)
/// Mode.global = Global
const _modeOrder = [Mode.rule, Mode.direct, Mode.global];

String _modeLabel(Mode mode) => switch (mode) {
      Mode.rule => Intl.message("smart"),
      Mode.direct => Intl.message("rules"),
      Mode.global => Intl.message("global"),
    };

Widget _modeIcon(Mode mode, {double size = 18}) => switch (mode) {
      Mode.rule => HugeIcon(
          icon: HugeIcons.strokeRoundedAiBrain02,
          size: size,
        ),
      Mode.direct => HugeIcon(
          icon: HugeIcons.strokeRoundedFilter,
          size: size,
        ),
      Mode.global => HugeIcon(
          icon: HugeIcons.strokeRoundedGlobe02,
          size: size,
        ),
    };

class OutboundMode extends StatelessWidget {
  const OutboundMode({super.key});

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(2);
    return SizedBox(
      height: height,
      child: Consumer(
        builder: (_, ref, __) {
          final mode = ref.watch(
            patchClashConfigProvider.select(
              (state) => state.mode,
            ),
          );
          return Theme(
              data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent),
              child: CommonCard(
                onPressed: () {},
                info: Info(
                  label: appLocalizations.outboundMode,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 12,
                    bottom: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final item in _modeOrder)
                        Flexible(
                          fit: FlexFit.tight,
                          child: ListItem.radio(
                            dense: true,
                            horizontalTitleGap: 4,
                            padding: EdgeInsets.only(
                              left: 12.ap,
                              right: 16.ap,
                            ),
                            delegate: RadioDelegate(
                              value: item,
                              groupValue: mode,
                              onChanged: (value) async {
                                if (value == null) {
                                  return;
                                }
                                globalState.appController.changeMode(value);
                              },
                            ),
                            title: Text(
                              _modeLabel(item),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.toSoftBold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ));
        },
      ),
    );
  }
}

class OutboundModeV2 extends StatelessWidget {
  const OutboundModeV2({super.key});

  Color _getTextColor(BuildContext context, Mode mode) => switch (mode) {
        Mode.rule => context.colorScheme.onSecondaryContainer,
        Mode.global => context.colorScheme.onPrimaryContainer,
        Mode.direct => context.colorScheme.onTertiaryContainer,
      };

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(0.72);
    return SizedBox(
      height: height,
      child: CommonCard(
        padding: EdgeInsets.zero,
        child: Consumer(
          builder: (_, ref, __) {
            final mode = ref.watch(
              patchClashConfigProvider.select(
                (state) => state.mode,
              ),
            );
            final thumbColor = switch (mode) {
              Mode.rule => context.colorScheme.secondaryContainer,
              Mode.global => globalState.theme.darken3PrimaryContainer,
              Mode.direct => context.colorScheme.tertiaryContainer,
            };
            return Container(
              constraints: const BoxConstraints.expand(),
              child: CommonTabBar<Mode>(
                children: Map.fromEntries(
                  _modeOrder.map(
                    (item) => MapEntry(
                      item,
                      Container(
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(),
                        height: height - 16,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _modeIcon(item, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _modeLabel(item),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.adjustSize(1)
                                  .copyWith(
                                    color: item == mode
                                        ? _getTextColor(
                                            context,
                                            item,
                                          )
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                groupValue: mode,
                onValueChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  globalState.appController.changeMode(value);
                },
                thumbColor: thumbColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
