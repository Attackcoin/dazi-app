// client/test/core/theme/dazi_colors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dazi_app/core/theme/dazi_colors.dart';

void main() {
  group('DaziColors', () {
    test('dark scheme has correct base color', () {
      expect(DaziColors.dark.base.value, 0xFF0F0A1A);
    });

    test('light scheme has correct base color', () {
      expect(DaziColors.light.base.value, 0xFFF8F5FF);
    });

    test('dark text primary is 95% white', () {
      expect(DaziColors.dark.textPrimary.alpha, closeTo(0xF2, 1));
    });

    test('light text primary is 90% black', () {
      expect(DaziColors.light.textPrimary.alpha, closeTo(0xE6, 1));
    });

    test('heroGradientColors has 3 stops', () {
      expect(DaziColors.heroGradientColors.length, 3);
    });

    test('dark glassL1Bg is 4% white', () {
      expect(DaziColors.dark.glassL1Bg.alpha, closeTo(0x0A, 1));
    });
  });
}
