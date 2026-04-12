import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// Glass Morph 输入框。3 态：Normal / Focused（粉色发光边框）/ Error。
class GlassInput extends StatelessWidget {
  const GlassInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final c = gt.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    final focusBorderColor = hasError ? c.error.withValues(alpha: 0.3) : c.primary.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.space4, left: Spacing.space4),
            child: Text(label!, style: TextStyle(fontSize: 12, color: c.textTertiary)),
          ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          cursorColor: c.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.textTertiary),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: c.glassL1Bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.glassL1Border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.glassL1Border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: focusBorderColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.error.withValues(alpha: 0.3)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.error.withValues(alpha: 0.5), width: 1.5),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.space4, left: Spacing.space4),
            child: Text(errorText!, style: TextStyle(fontSize: 11, color: c.error)),
          ),
      ],
    );
  }
}
