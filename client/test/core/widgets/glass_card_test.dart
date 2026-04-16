import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazi_app/core/widgets/glass_card.dart';
import 'package:dazi_app/core/theme/glass_theme.dart';

void main() {
  Widget wrap(Widget child, {bool isDark = true}) {
    return MaterialApp(
      home: GlassTheme(
        data: isDark ? GlassThemeData.dark : GlassThemeData.light,
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('GlassCard renders child', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(child: Text('hello')),
    ));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('GlassCard without blur has no BackdropFilter', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(child: SizedBox()),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('GlassCard with useBlur has BackdropFilter', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(useBlur: true, child: SizedBox()),
    ));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('GlassCard onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      GlassCard(onTap: () => tapped = true, child: const Text('tap me')),
    ));
    await tester.tap(find.text('tap me'));
    expect(tapped, isTrue);
  });
}
