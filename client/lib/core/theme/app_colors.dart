import 'package:flutter/material.dart';

/// 搭子 App 品牌色系。与 H5 分享页保持一致。
@Deprecated('Use DaziColors via GlassTheme.of(context).colors instead. Will be removed after all pages migrated.')
class AppColors {
  AppColors._();

  // 主色：珊瑚粉红（温暖、友好）
  static const Color primary = Color(0xFFFF6B9D);
  static const Color primaryLight = Color(0xFFFF8A65);
  static const Color primaryDark = Color(0xFFE91E63);

  // 辅助色：紫色用于渐变点缀
  static const Color accent = Color(0xFFA855F7);

  // 中性色
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF5F5F7);
  static const Color border = Color(0xFFE5E5E7);

  // 文字
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);

  // 语义色
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // 功能色
  static const Color starColor = Color(0xFFFFC107);   // 星评颜色（琥珀）
  static const Color successGreen = Color(0xFF4CAF50); // 成功状态绿色

  // 性别标识
  static const Color male = Color(0xFF3B82F6);
  static const Color female = Color(0xFFEC4899);

  // 主题渐变
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary, accent],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryLight, primary],
  );
}
