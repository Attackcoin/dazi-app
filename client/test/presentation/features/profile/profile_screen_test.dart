import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/app_user.dart';
import 'package:dazi_app/data/models/application.dart';
import 'package:dazi_app/data/models/post.dart';
import 'package:dazi_app/data/repositories/application_repository.dart';
import 'package:dazi_app/data/repositories/auth_repository.dart';
import 'package:dazi_app/data/repositories/post_repository.dart';
import 'package:dazi_app/data/repositories/user_repository.dart';
import 'package:dazi_app/presentation/features/profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 假 FirebaseAuth User —— 只实现 uid getter，其它方法通过 noSuchMethod 抛出。
/// 足以覆盖 profile_screen 的 `authStateProvider.valueOrNull?.uid` 访问。
class _FakeAuthUser implements User {
  _FakeAuthUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 构造最小化 AppUser。
AppUser _fakeUser({
  String id = 'self-uid',
  String name = '测试昵称',
  String bio = '',
  String gender = 'female',
  int? birthYear = 1998,
  String city = '上海',
  List<String> tags = const ['咖啡', '徒步'],
  bool sesameAuthorized = true,
  int totalMeetups = 3,
  List<String> badges = const ['new_host'],
}) =>
    AppUser(
      id: id,
      name: name,
      avatar: '',
      bio: bio,
      gender: gender,
      birthYear: birthYear,
      phone: '',
      tags: tags,
      rating: 4.8,
      reviewCount: 12,
      ghostCount: 0,
      isRestricted: false,
      verificationLevel: 1,
      sesameAuthorized: sesameAuthorized,
      totalMeetups: totalMeetups,
      badges: badges,
      city: city,
      blockedUsers: const [],
      createdAt: null,
      lastActive: null,
    );

/// 假 auth state —— 只用 uid 字段，所以我们无法真实构造 FirebaseAuth User；
/// 直接 override authStateProvider 的 stream 发 null/非 null；
/// 对于登录态测试，我们直接 override userByIdProvider 覆盖数据。
List<Override> _baseOverrides({
  required AppUser? user,
  required bool loggedIn,
  String uid = 'self-uid',
  List<Post> posts = const [],
  List<Application> applications = const [],
}) {
  return [
    // loggedIn = false → authStateProvider 发 null
    if (!loggedIn)
      authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
    // loggedIn = true → 这里 override currentAppUserProvider 并不够，
    // profile 屏用的是 authStateProvider.uid 和 userByIdProvider。
    // 无法构造 FirebaseAuth User，但可以 override userByIdProvider 直接提供数据。
    userByIdProvider(uid).overrideWith((ref) => Stream.value(user)),
    postsByUserProvider(uid).overrideWith((ref) => Stream.value(posts)),
    applicationsByApplicantProvider(uid)
        .overrideWith((ref) => Stream.value(applications)),
  ];
}

/// 将被测 widget 包裹在必要的 Provider 中（GlassTheme + MaterialApp + ProviderScope）。
/// ProfileScreen 及其子 widget 均调用 GlassTheme.of(context)；
/// GlassTheme 置于 MaterialApp 之上，确保 BottomSheet / PopupMenu 等 overlay
/// 路由也能正确访问到 GlassTheme。
Widget _buildProfileApp({
  required Widget child,
  required List<Override> overrides,
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
  testWidgets('ProfileScreen 未登录（无 uid 参数）显示登录引导', (tester) async {
    await tester.pumpWidget(
      _buildProfileApp(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const ProfileScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('尚未登录'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('ProfileScreen 渲染他人主页（未登录 + 显式 uid）', (tester) async {
    // 未登录但路由显式传入 uid → isSelf=false,走他人视角。
    final user = _fakeUser();
    await tester.pumpWidget(
      _buildProfileApp(
        overrides: _baseOverrides(
          user: user,
          loggedIn: false,
          uid: 'self-uid',
        ),
        child: const ProfileScreen(uid: 'self-uid'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('测试昵称'), findsOneWidget);
    expect(find.text('上海'), findsOneWidget);
    expect(find.textContaining('岁'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
    expect(find.text('信用'), findsOneWidget);
    expect(find.text('咖啡'), findsOneWidget);
    expect(find.text('徒步'), findsOneWidget);
    // 他人主页 Tab 文案为第三人称
    expect(find.text('TA 发布的'), findsOneWidget);
    expect(find.text('TA 申请的'), findsOneWidget);
    expect(find.text('参加过'), findsOneWidget);
    // isSelf=false → 显示更多菜单而非编辑/设置
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets('ProfileScreen 自己视角（已登录 + 无 uid 参数）显示编辑/设置按钮',
      (tester) async {
    // 真正的 self 路径:authState 有 uid,路由未显式传 uid → isSelf=true。
    final user = _fakeUser();
    await tester.pumpWidget(
      _buildProfileApp(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream<User?>.value(_FakeAuthUser('self-uid')),
          ),
          userByIdProvider('self-uid')
              .overrideWith((ref) => Stream.value(user)),
          postsByUserProvider('self-uid')
              .overrideWith((ref) => Stream.value(const <Post>[])),
          applicationsByApplicantProvider('self-uid')
              .overrideWith((ref) => Stream.value(const <Application>[])),
        ],
        child: const ProfileScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('测试昵称'), findsOneWidget);
    // 自己视角 Tab 文案为第一人称
    expect(find.text('我发布的'), findsOneWidget);
    expect(find.text('我申请的'), findsOneWidget);
    expect(find.text('参加过'), findsOneWidget);
    // isSelf=true → 显示编辑 + 设置,不显示更多菜单
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('ProfileScreen 他人视角显示举报/拉黑菜单', (tester) async {
    final other = _fakeUser(id: 'other-uid', name: '小明', sesameAuthorized: false);
    await tester.pumpWidget(
      _buildProfileApp(
        overrides: _baseOverrides(
          user: other,
          loggedIn: false,
          uid: 'other-uid',
        ),
        child: const ProfileScreen(uid: 'other-uid'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('小明'), findsOneWidget);
    // 无编辑按钮
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    // 无信用徽章
    expect(find.text('信用'), findsNothing);
    // 更多按钮
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    // 打开菜单
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('举报'), findsOneWidget);
    expect(find.text('拉黑'), findsOneWidget);
  });

  testWidgets('ProfileScreen 用户不存在显示空态文案', (tester) async {
    await tester.pumpWidget(
      _buildProfileApp(
        overrides: _baseOverrides(
          user: null,
          loggedIn: false,
          uid: 'ghost-uid',
        ),
        child: const ProfileScreen(uid: 'ghost-uid'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('用户不存在或已注销'), findsOneWidget);
  });

  testWidgets('ProfileScreen 加载中显示骨架屏', (tester) async {
    // 构造永不 emit 的 stream
    final never = StreamController<AppUser?>();
    addTearDown(() => never.close());
    await tester.pumpWidget(
      _buildProfileApp(
        overrides: [
          userByIdProvider('slow-uid')
              .overrideWith((ref) => never.stream),
          postsByUserProvider('slow-uid')
              .overrideWith((ref) => Stream.value(const <Post>[])),
          applicationsByApplicantProvider('slow-uid')
              .overrideWith((ref) => Stream.value(const <Application>[])),
        ],
        child: const ProfileScreen(uid: 'slow-uid'),
      ),
    );
    await tester.pump();

    // 骨架渐变头存在，但昵称不存在
    expect(find.text('测试昵称'), findsNothing);
  });
}
