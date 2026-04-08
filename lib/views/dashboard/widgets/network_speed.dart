import 'package:dropweb/common/common.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/providers/app.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network speed card with **separate rebuild scopes** for chart and text.
///
/// Previously a single `Consumer` wrapped the entire card, so every traffic
/// update (fired by the 2-second state.dart update loop) rebuilt:
/// the CommonCard chrome + LineChart subtree + Text label, all at once.
///
/// Now:
/// - [NetworkSpeed] is a plain [StatelessWidget] — never rebuilds.
/// - [_SpeedChart] is a [ConsumerWidget] that watches `trafficsProvider`
///   for the full point list (needed to draw the line chart).
/// - [_SpeedText] is a [ConsumerWidget] that uses
///   `trafficsProvider.select(...)` on a derived **display string**. Riverpod
///   rebuilds it only when the formatted string actually changes — String
///   has proper value equality, so stable speeds avoid rebuilds entirely.
class NetworkSpeed extends StatelessWidget {
  const NetworkSpeed({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: getWidgetHeight(2),
      child: CommonCard(
        onPressed: () {},
        info: Info(
          label: appLocalizations.networkSpeed,
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                child: _SpeedChart(),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Transform.translate(
                offset: const Offset(-16, -20),
                child: const _SpeedText(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedChart extends ConsumerWidget {
  const _SpeedChart();

  static const List<Point> _initPoints = [Point(0, 0), Point(1, 0)];

  List<Point> _buildPoints(List<Traffic> traffics) {
    final trafficPoints = traffics
        .asMap()
        .map(
          (index, e) => MapEntry(
            index,
            Point(
              (index + _initPoints.length).toDouble(),
              e.speed.toDouble(),
            ),
          ),
        )
        .values
        .toList();
    return [..._initPoints, ...trafficPoints];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffics = ref.watch(trafficsProvider).list;
    return LineChart(
      gradient: true,
      color: Theme.of(context).colorScheme.primary,
      points: _buildPoints(traffics),
    );
  }
}

class _SpeedText extends ConsumerWidget {
  const _SpeedText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the derived display string. Riverpod rebuilds this
    // widget only when the formatted string actually changes — String
    // has proper value equality. Even though the traffic list mutates
    // every tick, the up/down display values often stay identical on
    // idle connections, which eliminates the rebuild entirely.
    final speedText = ref.watch(
      trafficsProvider.select((t) {
        if (t.list.isEmpty) return '-↑   -↓';
        final last = t.list.last;
        return '${last.up}↑   ${last.down}↓';
      }),
    );
    final color = context.colorScheme.onSurfaceVariant.opacity80;
    return Text(
      speedText,
      style: context.textTheme.bodySmall?.copyWith(color: color),
    );
  }
}
