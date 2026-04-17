import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/circle.dart';
import 'package:dazi_app/data/repositories/circle_repository.dart';
import 'package:dazi_app/presentation/features/circles/circles_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: GlassTheme(
      data: GlassThemeData.dark,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: child,
      ),
    ),
  );
}

Circle _fakeCircle({
  String id = 'c1',
  String name = '跑步爱好者',
  String description = '每周三次晨跑',
  String category = '运动',
  String icon = '🏃',
  int memberCount = 42,
  int postCount = 15,
}) =>
    Circle(
      id: id,
      name: name,
      description: description,
      category: category,
      icon: icon,
      coverImage: '',
      memberCount: memberCount,
      postCount: postCount,
      createdBy: 'u1',
      creatorName: '张三',
    );

void main() {
  testWidgets('CirclesScreen —— loading 态显示进度指示器', (tester) async {
    final controller = StreamController<List<Circle>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          circlesProvider.overrideWith((ref) => controller.stream),
        ],
        child: const CirclesScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('CirclesScreen —— 空列表显示空态', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          circlesProvider.overrideWith(
            (ref) => Stream.value(<Circle>[]),
          ),
        ],
        child: const CirclesScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
  });

  testWidgets('CirclesScreen —— 有数据时显示圈子卡片', (tester) async {
    final circles = [
      _fakeCircle(id: 'c1', name: '跑步爱好者', memberCount: 42),
      _fakeCircle(id: 'c2', name: '吃货联盟', icon: '🍔', memberCount: 88),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          circlesProvider.overrideWith(
            (ref) => Stream.value(circles),
          ),
        ],
        child: const CirclesScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('跑步爱好者'), findsOneWidget);
    expect(find.text('吃货联盟'), findsOneWidget);
  });

  testWidgets('CirclesScreen —— 错误态显示加载失败', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          circlesProvider.overrideWith(
            (ref) => Stream<List<Circle>>.error(Exception('network')),
          ),
        ],
        child: const CirclesScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('CirclesScreen —— 创建按钮存在', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          circlesProvider.overrideWith(
            (ref) => Stream.value(<Circle>[]),
          ),
        ],
        child: const CirclesScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('CirclesScreen —— 卡片显示描述和成员数', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          circlesProvider.overrideWith(
            (ref) => Stream.value([
              _fakeCircle(
                name: '读书会',
                description: '每月一本好书',
                memberCount: 23,
              ),
            ]),
          ),
        ],
        child: const CirclesScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('读书会'), findsOneWidget);
    expect(find.text('每月一本好书'), findsOneWidget);
  });
}
