import 'package:flutter/material.dart';

class ScrollOverBuilder extends StatefulWidget {
  const ScrollOverBuilder({
    super.key,
    required this.builder,
  });
  final Widget Function(bool isOver) builder;

  @override
  State<ScrollOverBuilder> createState() => _ScrollOverBuilderState();
}

class _ScrollOverBuilderState extends State<ScrollOverBuilder> {
  final isOverNotifier = ValueNotifier<bool>(false);

  @override
  void dispose() {
    isOverNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (scrollNotification) {
          isOverNotifier.value = scrollNotification.metrics.maxScrollExtent > 0;
          return true;
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: isOverNotifier,
          builder: (_, isOver, __) => widget.builder(isOver),
        ),
      );
}

typedef StateWidgetBuilder<T> = Widget Function(T state);

typedef StateAndChildWidgetBuilder<T> = Widget Function(T state, Widget? child);
