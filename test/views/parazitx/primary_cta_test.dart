import 'package:dropweb/views/parazitx/primary_cta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PrimaryCta', () {
    testWidgets('renders the label and supporting text', (tester) async {
      await tester.pumpWidget(_wrap(
        PrimaryCta(
          label: 'Включить режим стабильности',
          supportingText: 'Сессия VK подключена.',
          onPressed: () {},
        ),
      ));

      expect(find.text('Включить режим стабильности'), findsOneWidget);
      expect(find.text('Сессия VK подключена.'), findsOneWidget);
    });

    testWidgets('button is disabled when onPressed is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const PrimaryCta(
          label: 'Подключаем...',
          supportingText: 'Обычно до 15 секунд.',
          onPressed: null,
          showProgress: true,
        ),
      ));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('fires onPressed when tapped and enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(
        PrimaryCta(
          label: 'Войти и включить',
          supportingText: 'Нужна сессия VK.',
          onPressed: () => taps++,
        ),
      ));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
