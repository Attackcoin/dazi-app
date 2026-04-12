// client/lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

import 'dazi_colors.dart';
import 'spacing.dart';

/// 搭子 App Material ThemeData 工厂。
///
/// 使用 [AppTheme.dark] 和 [AppTheme.light] 获取对应主题。
/// Glass Morph 特有属性（玻璃层级等）通过 [GlassTheme] 获取。
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(DaziColors.dark, Brightness.dark);
  static ThemeData get light => _build(DaziColors.light, Brightness.light);

  static ThemeData _build(DaziColorScheme c, Brightness brightness) {
    final textTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.3),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.3),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textSecondary, height: 1.5),
      bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: c.textTertiary, height: 1.4),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.textTertiary, height: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.textOnPrimary,
        secondary: c.accent,
        onSecondary: c.textOnPrimary,
        error: c.error,
        onError: c.textOnPrimary,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      scaffoldBackgroundColor: c.base,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.elevated.withValues(alpha: 0.85),
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: c.glassL1Bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: c.glassL1Border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: c.glassL1Border,
        thickness: 0.5,
        space: 0.5,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
    );
  }
}
