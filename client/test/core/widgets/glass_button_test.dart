import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazi_app/core/widgets/glass_button.dart';
import 'package:dazi_app/core/theme/glass_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: GlassTheme(
        data: GlassThemeData.dark,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('GlassButton shows label', (tester) async {
    await tester.pumpWidget(wrap(
      GlassButton(label: '加入', onPressed: () {}),
    ));
    expect(find.text('加入'), findsOneWidget);
  });

  testWidgets('GlassButton onPressed fires', (tester) async {
    var pressed = false;
    await tester.pumpWidget(wrap(
      GlassButton(label: 'tap', onPressed: () => pressed = true),
    ));
    await tester.tap(find.text('tap'));
    expect(pressed, isTrue);
  });

  testWidgets('GlassButton disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassButton(label: 'disabled', onPressed: null),
    ));
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0.5);
  });

  testWidgets('GlassButton shows loading indicator', (tester) async {
    await tester.pumpWidget(wrap(
      GlassButton(label: 'loading', onPressed: () {}, isLoading: true),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
