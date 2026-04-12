// client/lib/core/theme/glass_theme.dart
import 'package:flutter/material.dart';

import 'dazi_colors.dart';

/// Glass Morph 主题数据，通过 [GlassTheme.of(context)] 获取。
class GlassThemeData {
  const GlassThemeData({
    required this.colors,
    required this.isDark,
  });

  final DaziColorScheme colors;
  final bool isDark;

  /// 根据 level (1/2/3) 返回对应的玻璃背景色。
  Color glassBackground(int level) {
    switch (level) {
      case 1: return colors.glassL1Bg;
      case 2: return colors.glassL2Bg;
      case 3: return colors.glassL3Bg;
      default: return colors.glassL1Bg;
    }
  }

  /// 根据 level (1/2/3) 返回对应的玻璃边框色。
  Color glassBorder(int level) {
    switch (level) {
      case 1: return colors.glassL1Border;
      case 2: return colors.glassL2Border;
      case 3: return colors.glassL3Border;
      default: return colors.glassL1Border;
    }
  }

  /// 卡片图片区占位渐变色。
  List<Color> get cardGlowColors =>
      isDark ? DaziColors.cardGlowDarkColors : DaziColors.cardGlowLightColors;

  static const dark = GlassThemeData(colors: DaziColors.dark, isDark: true);
  static const light = GlassThemeData(colors: DaziColors.light, isDark: false);
}

/// 提供 [GlassThemeData] 给子树。
class GlassTheme extends InheritedWidget {
  const GlassTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final GlassThemeData data;

  static GlassThemeData of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<GlassTheme>();
    assert(widget != null, 'No GlassTheme found in context');
    return widget!.data;
  }

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => data != oldWidget.data;
}
