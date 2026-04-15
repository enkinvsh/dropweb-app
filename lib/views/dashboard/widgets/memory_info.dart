import 'dart:async';
import 'dart:io';

import 'package:dropweb/clash/clash.dart';
import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/common.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

final _memoryInfoStateNotifier = ValueNotifier<TrafficValue>(
  const TrafficValue(value: 0),
);

class MemoryInfo extends StatefulWidget {
  const MemoryInfo({super.key});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _updateMemory();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _updateMemory() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rss = ProcessInfo.currentRss;
      _memoryInfoStateNotifier.value = TrafficValue(
        value: clashLib != null ? rss : await clashCore.getMemory() + rss,
      );
      timer = Timer(const Duration(seconds: 2), () async {
        _updateMemory();
      });
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: Info(
            label: appLocalizations.memoryInfo,
          ),
          onPressed: clashCore.requestGc,
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(
              top: 0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: globalState.measure.bodyMediumHeight + 2,
                  child: ValueListenableBuilder(
                    valueListenable: _memoryInfoStateNotifier,
                    builder: (_, trafficValue, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          trafficValue.showValue,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          trafficValue.showUnit,
                          style: context.textTheme.bodyMedium?.toLight
                              .adjustSize(1),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      );
}
