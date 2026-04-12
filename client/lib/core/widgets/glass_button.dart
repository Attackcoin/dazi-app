import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dazi_colors.dart';
import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

enum GlassButtonVariant { primary, secondary, ghost, danger }

/// Glass Morph 按钮。按下缩小 0.95 + 触觉反馈。
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.95,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _scaleCtrl.reverse();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _onTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final c = gt.colors;
    final enabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    Border? border;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case GlassButtonVariant.primary:
        bg = Colors.transparent;
        fg = c.textOnPrimary;
        shadows = [BoxShadow(color: c.primaryGlow, blurRadius: 20, offset: const Offset(0, 4))];
      case GlassButtonVariant.secondary:
        bg = c.primary.withValues(alpha: 0.12);
        fg = c.textAccent;
        border = Border.all(color: c.primary.withValues(alpha: 0.25));
      case GlassButtonVariant.ghost:
        bg = c.glassL1Bg;
        fg = c.textSecondary;
        border = Border.all(color: c.glassL1Border);
      case GlassButtonVariant.danger:
        bg = c.error.withValues(alpha: 0.12);
        fg = const Color(0xFFF87171);
        border = Border.all(color: c.error.withValues(alpha: 0.25));
    }

    final isPrimary = widget.variant == GlassButtonVariant.primary;

    return ScaleTransition(
      scale: _scaleCtrl,
      child: GestureDetector(
        onTapDown: enabled ? _onTapDown : null,
        onTapUp: enabled ? _onTapUp : null,
        onTapCancel: enabled ? _onTapCancel : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
            decoration: BoxDecoration(
              color: isPrimary ? null : bg,
              gradient: isPrimary
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: DaziColors.heroGradientColors,
                    )
                  : null,
              borderRadius: BorderRadius.circular(Radii.button),
              border: border,
              boxShadow: enabled ? shadows : null,
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.space8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    ),
                  )
                else if (widget.icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.space8),
                    child: Icon(widget.icon, size: 18, color: fg),
                  ),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
