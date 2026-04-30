import 'dart:math';

import 'package:dropweb/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class DonutChartData {
  const DonutChartData({
    required double value,
    required this.color,
  }) : _value = value + 1;
  final double _value;
  final Color color;

  double get value => _value;

  @override
  String toString() => 'DonutChartData{_value: $_value}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DonutChartData &&
          runtimeType == other.runtimeType &&
          _value == other._value &&
          color == other.color;

  @override
  int get hashCode => _value.hashCode ^ color.hashCode;
}

class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.data,
    this.duration = commonDuration,
  });
  final List<DonutChartData> data;
  final Duration duration;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<DonutChartData> _oldData;

  @override
  void initState() {
    super.initState();
    _oldData = widget.data;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
  }

  @override
  void didUpdateWidget(DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Compare by value (DonutChartData has structural equality), not by
    // list identity. The traffic-usage parent allocates a fresh list of
    // DonutChartData every traffic tick — identity comparison would
    // restart the animation even when the underlying values are
    // unchanged (idle connection, same up/down totals).
    if (!listEquals(oldWidget.data, widget.data)) {
      _oldData = oldWidget.data;
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => CustomPaint(
          painter: DonutChartPainter(
            _oldData,
            widget.data,
            _animationController.value,
          ),
        ),
      );
}

class DonutChartPainter extends CustomPainter {
  DonutChartPainter(this.oldData, this.newData, this.progress);
  final List<DonutChartData> oldData;
  final List<DonutChartData> newData;
  final double progress;

  double _logTransform(double value) {
    const base = 10.0;
    const minValue = 0.1;
    if (value < minValue) return 0;
    return log(value) / log(base) + 1;
  }

  double _expTransform(double value) {
    const base = 10.0;
    if (value <= 0) return 0;
    return pow(base, value - 1).toDouble();
  }

  // Compute interpolated data lazily but exactly ONCE per painter instance.
  // Previously this was a getter, so any caller (e.g. `paint` itself, or any
  // future call site) would re-run the log/pow loop and re-allocate the
  // result list every time it was read. With `late final`, the first read
  // memoises the result on the painter instance.
  late final List<DonutChartData> interpolatedData = _computeInterpolatedData();

  List<DonutChartData> _computeInterpolatedData() {
    if (oldData.length != newData.length) return newData;
    return List.generate(newData.length, (index) {
      final oldValue = oldData[index].value;
      final newValue = newData[index].value;
      final logOldValue = _logTransform(oldValue);
      final logNewValue = _logTransform(newValue);
      final interpolatedLogValue =
          logOldValue + (logNewValue - logOldValue) * progress;

      final interpolatedValue = _expTransform(interpolatedLogValue);

      return DonutChartData(
        value: interpolatedValue,
        color: newData[index].color,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 10.0.ap;
    final radius = min(size.width / 2, size.height / 2) - strokeWidth / 2;

    final gapAngle = 2 * asin(strokeWidth * 1 / (2 * radius)) * 1.2;

    final data = interpolatedData;
    final total = data.fold<double>(
      0,
      (sum, item) => sum + item.value,
    );

    if (total <= 0) return;

    final availableAngle = 2 * pi - (data.length * gapAngle);
    var startAngle = -pi / 2 + gapAngle / 2;

    for (final item in data) {
      final sweepAngle = availableAngle * (item.value / total);

      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = item.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(DonutChartPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      !listEquals(oldDelegate.oldData, oldData) ||
      !listEquals(oldDelegate.newData, newData);
}
