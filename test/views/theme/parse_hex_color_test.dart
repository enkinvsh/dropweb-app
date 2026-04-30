import 'package:dropweb/views/theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseHexColor', () {
    test('accepts #RRGGBB', () {
      expect(parseHexColor('#22C55E'), 0xFF22C55E);
    });

    test('accepts RRGGBB without leading hash', () {
      expect(parseHexColor('22C55E'), 0xFF22C55E);
    });

    test('is case-insensitive', () {
      expect(parseHexColor('#22c55e'), 0xFF22C55E);
    });

    test('trims surrounding whitespace', () {
      expect(parseHexColor('  #22C55E  '), 0xFF22C55E);
    });

    test('expands #RGB shorthand', () {
      expect(parseHexColor('#0F0'), 0xFF00FF00);
      expect(parseHexColor('0F0'), 0xFF00FF00);
    });

    test('forces alpha to 0xFF', () {
      expect(parseHexColor('#000000'), 0xFF000000);
      expect(parseHexColor('#FFFFFF'), 0xFFFFFFFF);
    });

    test('rejects empty input', () {
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('   '), isNull);
    });

    test('rejects invalid characters', () {
      expect(parseHexColor('#ZZZZZZ'), isNull);
      expect(parseHexColor('22C55G'), isNull);
    });

    test('rejects wrong-length input', () {
      expect(parseHexColor('#1234'), isNull);
      expect(parseHexColor('#1234567'), isNull);
      expect(parseHexColor('#12'), isNull);
    });

    test('rejects bare hash', () {
      expect(parseHexColor('#'), isNull);
    });
  });
}
