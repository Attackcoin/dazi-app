import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/core/widgets/error_retry_view.dart';

Widget _wrap(Widget child) {
  return GlassTheme(
    data: GlassThemeData.light,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('渲染错误消息和重试按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(ErrorRetryView(onRetry: () {}, message: '测试失败')),
    );
    expect(find.text('测试失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('默认消息', (tester) async {
    await tester.pumpWidget(_wrap(ErrorRetryView(onRetry: () {})));
    expect(find.text('加载失败，请重试'), findsOneWidget);
  });

  testWidgets('点击重试触发 onRetry', (tester) async {
    int called = 0;
    await tester.pumpWidget(
      _wrap(ErrorRetryView(onRetry: () => called++)),
    );
    await tester.tap(find.text('重试'));
    expect(called, 1);
  });

  testWidgets('sliver 分支：渲染 SliverFillRemaining', (tester) async {
    await tester.pumpWidget(
      GlassTheme(
        data: GlassThemeData.light,
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                ErrorRetryView(onRetry: () {}, sliver: true),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SliverFillRemaining), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
