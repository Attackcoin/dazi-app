import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/app_user.dart';
import 'package:dazi_app/data/models/post.dart';
import 'package:dazi_app/data/repositories/auth_repository.dart';
import 'package:dazi_app/data/repositories/post_repository.dart';
import 'package:dazi_app/data/services/location_service.dart';
import 'package:dazi_app/presentation/features/home/home_screen.dart';
import 'package:dazi_app/presentation/features/home/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试用假 LocationService：立即返回 null，避免 pumpAndSettle 卡在定位 IO。
class _FakeLocationService extends LocationService {
  @override
  Future<LocationResult?> getCurrentCity() async => null;
}

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

Widget _wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: [
      // 阻止 CityPicker 调用真实 Geolocator，避免 pumpAndSettle 挂起
      locationServiceProvider.overrideWithValue(_FakeLocationService()),
      ...overrides,
    ],
    child: const GlassTheme(
      data: GlassThemeData.dark,
      child: MaterialApp(
        home: Scaffold(body: HomeScreen()),
      ),
    ),
  );
}

void main() {
  testWidgets('HomeScreen loading 态显示骨架屏而不是 CircularProgressIndicator',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      currentAppUserProvider.overrideWith(
        (ref) => Stream<AppUser?>.value(_fakeUser()),
      ),
      feedProvider.overrideWith(
        // 永不 emit 的 stream → 保持 loading
        (ref, q) => const Stream<List<Post>>.empty()
            .asyncMap((e) async => e)
            .asBroadcastStream(),
      ),
    ]));
    await tester.pump();

    expect(find.byType(PostCardSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('HomeScreen error 态显示重试按钮和用户友好文案',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      currentAppUserProvider.overrideWith(
        (ref) => Stream<AppUser?>.value(_fakeUser()),
      ),
      feedProvider.overrideWith(
        (ref, q) => Stream<List<Post>>.error(Exception('boom')),
      ),
    ]));
    // 等 stream error 传播
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('HomeScreen 包裹 RefreshIndicator 启用下拉刷新',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      currentAppUserProvider.overrideWith(
        (ref) => Stream<AppUser?>.value(_fakeUser()),
      ),
      feedProvider.overrideWith(
        (ref, q) => const Stream<List<Post>>.empty()
            .asyncMap((e) async => e)
            .asBroadcastStream(),
      ),
    ]));
    await tester.pump();

    expect(find.byType(RefreshIndicator), findsOneWidget);
  });

  testWidgets('HomeScreen 点击城市触发 CityPicker bottom sheet',
      (tester) async {
    await tester.pumpWidget(_wrap(overrides: [
      currentAppUserProvider.overrideWith(
        (ref) => Stream<AppUser?>.value(_fakeUser()),
      ),
      feedProvider.overrideWith(
        (ref, q) => Stream<List<Post>>.value(const []),
      ),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 当前城市应为 fakeUser 的 '北京'
    expect(find.text('北京'), findsOneWidget);
    await tester.tap(find.text('北京'));
    await tester.pumpAndSettle();

    // sheet 弹出后应看到"选择城市"标题 + 至少 2 个候选
    expect(find.text('选择城市'), findsOneWidget);
    expect(find.text('上海'), findsOneWidget);
    expect(find.text('广州'), findsOneWidget);
  });
}
