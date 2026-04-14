import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// 通用错误重试视图（T1 2026-04-13 组件化去重）。
/// 统一 6+ 处散落的 Column+Icon+FilledButton.tonal 模式，
/// 颜色走 [GlassTheme]，间距走 [Spacing]。
///
/// 不向用户暴露错误字面量，仅 [debugPrint] 记录。
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.onRetry,
    this.error,
    this.message = '加载失败，请重试',
    this.sliver = false,
  });

  final Object? error;
  final VoidCallback onRetry;
  final String message;
  final bool sliver;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      debugPrint('[ErrorRetryView] $error');
    }
    final gt = GlassTheme.of(context);
    final body = Padding(
      padding: const EdgeInsets.all(Spacing.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: gt.colors.textTertiary),
          const SizedBox(height: Spacing.space12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: gt.colors.textSecondary),
          ),
          const SizedBox(height: Spacing.space20),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );

    if (sliver) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: body),
      );
    }
    return Center(child: body);
  }
}
