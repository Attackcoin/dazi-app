import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 页面背景光斑容器。在 [child] 底层放置 1-3 个径向渐变光斑。
class GlowBackground extends StatelessWidget {
  const GlowBackground({
    super.key,
    required this.child,
    this.globs = const [GlowGlob.topRight, GlowGlob.bottomLeft],
  });

  final Widget child;
  final List<GlowGlob> globs;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final opacity = gt.isDark ? 1.0 : 0.5;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: gt.colors.base),
        ),
        for (final glob in globs)
          Positioned(
            top: glob.top,
            bottom: glob.bottom,
            left: glob.left,
            right: glob.right,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: glob.size,
                height: glob.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glob.color, glob.color.withValues(alpha: 0)],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// 预定义光斑配置。
class GlowGlob {
  const GlowGlob({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final Color color;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  static const topRight = GlowGlob(
    color: Color(0x26FF6B9D),
    size: 280,
    top: -60,
    right: -60,
  );

  static const bottomLeft = GlowGlob(
    color: Color(0x1FA855F7),
    size: 220,
    bottom: 100,
    left: -40,
  );

  static const centerBlue = GlowGlob(
    color: Color(0x143B82F6),
    size: 200,
    top: 300,
    right: 20,
  );
}
