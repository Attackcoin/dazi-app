import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// Glass Morph 分类标签 pill。
class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final c = color ?? gt.colors.primary;
    final bgOpacity = selected ? 0.25 : 0.15;
    final borderOpacity = selected ? 0.35 : 0.2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.space12, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: bgOpacity),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.withValues(alpha: borderOpacity)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
