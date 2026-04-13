import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/app_user.dart';
import 'package:dazi_app/data/models/post.dart';
import 'package:dazi_app/data/repositories/auth_repository.dart';
import 'package:dazi_app/data/repositories/search_repository.dart';
import 'package:dazi_app/presentation/features/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造一个最小化的 AppUser —— 只保留 city 字段供 SearchScreen 使用。
AppUser _fakeUser() => AppUser(
      id: 'u1',
      name: '测试',
      avatar: '',
      bio: '',
      gender: 'male',
      birthYear: 2000,
      phone: '',
      tags: const [],
      rating: 5.0,
      reviewCount: 0,
      ghostCount: 0,
      isRestricted: false,
      verificationLevel: 1,
      sesameAuthorized: false,
      totalMeetups: 0,
      badges: const [],
      city: '北京',
      blockedUsers: const [],
      createdAt: null,
      lastActive: null,
    );

/// 将被测 widget 包裹在必要的 Provider 中：
/// - ProviderScope（含 overrides）
/// - MaterialApp
/// - GlassTheme（SearchScreen 及 GlassInput 均调用 GlassTheme.of(context)）
Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: GlassTheme(
      data: GlassThemeData.dark,
      child: MaterialApp(
        home: child,
      ),
    ),
  );
}

void main() {
  testWidgets('SearchScreen smoke —— 渲染、输入框、空态提示', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          // 覆盖 currentAppUserProvider，避免真实 Firestore 调用
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_fakeUser()),
          ),
        ],
        child: const SearchScreen(),
      ),
    );
    await tester.pump();

    // 输入框存在（GlassInput 内部包含 TextField）
    expect(find.byType(TextField), findsOneWidget);

    // 返回按钮存在
    expect(find.byType(BackButton), findsOneWidget);

    // 空 query 时显示引导文案
    expect(find.text('找你想要的搭子'), findsOneWidget);
    expect(find.textContaining('试试'), findsWidgets);
  });

  testWidgets('SearchScreen —— 输入后显示清除按钮', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_fakeUser()),
          ),
        ],
        child: const SearchScreen(),
      ),
    );
    await tester.pump();

    // 初始没有清除按钮
    expect(find.byIcon(Icons.cancel), findsNothing);

    await tester.enterText(find.byType(TextField), '火锅');
    await tester.pump();

    // 清除按钮应出现
    expect(find.byIcon(Icons.cancel), findsOneWidget);
  });

  testWidgets('SearchScreen —— 输入后 debounce 触发显示 loading 态', (tester) async {
    // StreamController 不 emit 任何事件，模拟持续 loading
    final pendingController = StreamController<List<Post>>();
    addTearDown(pendingController.close);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_fakeUser()),
          ),
          searchResultsProvider.overrideWith(
            (ref, q) => pendingController.stream,
          ),
        ],
        child: const SearchScreen(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '火锅');
    // 等待 debounce 300ms
    await tester.pump(const Duration(milliseconds: 350));
    // AsyncValue loading 态首帧
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('SearchScreen —— 错误态显示错误图标和重试按钮', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_fakeUser()),
          ),
          searchResultsProvider.overrideWith(
            (ref, q) =>
                Stream<List<Post>>.error(Exception('algolia down')),
          ),
        ],
        child: const SearchScreen(),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '火锅');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('搜索失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
