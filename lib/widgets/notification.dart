import 'package:dropweb/models/config.dart';
import 'package:dropweb/providers/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextScaleNotification extends StatelessWidget {

  const TextScaleNotification({
    super.key,
    required this.child,
    required this.onNotification,
  });
  final Widget child;
  final Function(TextScale textScale) onNotification;

  @override
  Widget build(BuildContext context) => Consumer(
      builder: (_, ref, child) {
        ref.listen(
          themeSettingProvider.select((state) => state.textScale),
          (prev, next) {
            if (prev != next) {
              onNotification(next);
            }
          },
        );
        return child!;
      },
      child: child,
    );
}
