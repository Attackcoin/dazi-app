// client/lib/core/theme/dazi_colors.dart
import 'dart:ui';

/// 搭子 App Glass Morph 双主题色彩系统。
///
/// 使用方式：DaziColors.dark.primary / DaziColors.light.primary
/// 或通过 GlassTheme.of(context).colors 获取当前主题的颜色。
class DaziColorScheme {
  const DaziColorScheme._({
    required this.base,
    required this.surface,
    required this.elevated,
    required this.primary,
    required this.accent,
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.textAccent,
    required this.male,
    required this.female,
    required this.starColor,
    required this.glassL1Bg,
    required this.glassL1Border,
    required this.glassL2Bg,
    required this.glassL2Border,
    required this.glassL3Bg,
    required this.glassL3Border,
    required this.primaryGlow,
    required this.accentGlow,
    required this.infoGlow,
    required this.successGlow,
    required this.errorGlow,
  });

  // 背景画布
  final Color base;
  final Color surface;
  final Color elevated;

  // 强调色
  final Color primary;
  final Color accent;
  final Color info;
  final Color success;
  final Color warning;
  final Color error;

  // 文字
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;
  final Color textAccent;

  // 性别 & 星评
  final Color male;
  final Color female;
  final Color starColor;

  // 玻璃层级
  final Color glassL1Bg;
  final Color glassL1Border;
  final Color glassL2Bg;
  final Color glassL2Border;
  final Color glassL3Bg;
  final Color glassL3Border;

  // 发光阴影
  final Color primaryGlow;
  final Color accentGlow;
  final Color infoGlow;
  final Color successGlow;
  final Color errorGlow;
}

class DaziColors {
  DaziColors._();

  static const dark = DaziColorScheme._(
    base: Color(0xFF0F0A1A),
    surface: Color(0xFF1A1025),
    elevated: Color(0xFF241830),
    primary: Color(0xFFFF6B9D),
    accent: Color(0xFFA855F7),
    info: Color(0xFF3B82F6),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    textPrimary: Color(0xF2FFFFFF),   // 95%
    textSecondary: Color(0xB3FFFFFF), // 70%
    textTertiary: Color(0x66FFFFFF),  // 40%
    textOnPrimary: Color(0xFFFFFFFF),
    textAccent: Color(0xFFFF8AB4),
    male: Color(0xFF3B82F6),
    female: Color(0xFFEC4899),
    starColor: Color(0xFFFFC107),
    glassL1Bg: Color(0x0AFFFFFF),     // 4%
    glassL1Border: Color(0x0FFFFFFF), // 6%
    glassL2Bg: Color(0x14FFFFFF),     // 8%
    glassL2Border: Color(0x1AFFFFFF), // 10%
    glassL3Bg: Color(0x1FFFFFFF),     // 12%
    glassL3Border: Color(0x26FFFFFF), // 15%
    primaryGlow: Color(0x4DFF6B9D),   // 30%
    accentGlow: Color(0x4DA855F7),
    infoGlow: Color(0x4D3B82F6),
    successGlow: Color(0x4D10B981),
    errorGlow: Color(0x4DEF4444),
  );

  static const light = DaziColorScheme._(
    base: Color(0xFFF8F5FF),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    primary: Color(0xFFFF6B9D),
    accent: Color(0xFF9333EA),
    info: Color(0xFF2563EB),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    textPrimary: Color(0xE6000000),   // 90%
    textSecondary: Color(0x99000000), // 60%
    textTertiary: Color(0x59000000),  // 35%
    textOnPrimary: Color(0xFFFFFFFF),
    textAccent: Color(0xFFD6336C),
    male: Color(0xFF2563EB),
    female: Color(0xFFDB2777),
    starColor: Color(0xFFF59E0B),
    glassL1Bg: Color(0xB3FFFFFF),     // 70%
    glassL1Border: Color(0x0F000000), // 6%
    glassL2Bg: Color(0xD9FFFFFF),     // 85%
    glassL2Border: Color(0x14000000), // 8%
    glassL3Bg: Color(0xF2FFFFFF),     // 95%
    glassL3Border: Color(0x26A855F7), // accent 15%
    primaryGlow: Color(0x33FF6B9D),   // 20%
    accentGlow: Color(0x339333EA),
    infoGlow: Color(0x332563EB),
    successGlow: Color(0x3310B981),
    errorGlow: Color(0x33EF4444),
  );

  // 共享渐变（不分主题）
  static const heroGradientColors = [Color(0xFFFF8A65), Color(0xFFFF6B9D), Color(0xFFA855F7)];
  static const cardGlowDarkColors = [Color(0x33FF6B9D), Color(0x33A855F7)];
  static const cardGlowLightColors = [Color(0x1AFF6B9D), Color(0x1AA855F7)];
}
