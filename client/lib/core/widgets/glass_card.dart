import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// Glass Morph 玻璃卡片。
///
/// 默认使用伪玻璃（半透明底色 + 边框 + BoxShadow）。
/// 仅 BottomSheet/Modal/NavBar 传 [useBlur: true] 启用真 BackdropFilter。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.level = 1,
    this.useBlur = false,
    this.blurSigma = 20.0,
    this.borderRadius,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final int level;
  final bool useBlur;
  final double blurSigma;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final bg = gt.glassBackground(level);
    final border = gt.glassBorder(level);
    final radius = borderRadius ?? BorderRadius.circular(Radii.card);

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: useBlur ? bg.withValues(alpha: bg.a * 0.5) : bg,
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
        boxShadow: gt.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );

    if (useBlur) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      );
    }

    return content;
  }
}
