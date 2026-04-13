// J0 Smoke：最小冒烟 —— 启动 app + 看到 splash → 登录页。
//
// 运行前：
//   cd <repo-root> && firebase emulators:start --only auth,firestore,functions,storage,database
//   cd client && flutter test integration_test/journey_smoke_test.dart
//
// T1a 未完成前可能因 firebase_options.dart 占位而编译失败；那时先跑：
//   flutterfire configure --project=<dev project>

import 'package:dazi_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/emulator_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootTestFirebase();
  });

  tearDown(() async {
    await signOutIfAny();
  });

  testWidgets('J0 冒烟 —— app 启动，渲染 splash 或登录页', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // splash 会很快跳到登录页（未登录）或首页（已登录）
    final hasLoginCta = find.textContaining('登录').evaluate().isNotEmpty ||
        find.textContaining('手机号').evaluate().isNotEmpty;
    final hasHomeCta = find.byIcon(Icons.home).evaluate().isNotEmpty ||
        find.textContaining('搭子').evaluate().isNotEmpty;

    expect(hasLoginCta || hasHomeCta, isTrue,
        reason: 'app 启动后既不在登录页也不在首页');
  });
}
