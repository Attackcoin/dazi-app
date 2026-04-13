// J4 个人主页 Journey：自己 / 他人 视角差异验证。
//
// 登录走 signInAndSeed（email/password），绕过 UI phone flow。

import 'package:dazi_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/emulator_setup.dart';
import 'helpers/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootTestFirebase();
  });

  tearDown(() async {
    await signOutIfAny();
  });

  testWidgets('J4 自己主页 —— Alice 看到编辑/设置按钮', (tester) async {
    await resetFirestore();
    await signInAndSeed(kTestUserAlice);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 进入 profile Tab（底部导航）
    await tester.tap(find.byIcon(Icons.person).last);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.textContaining('我发布的'), findsOneWidget);
  }, skip: true /* 需要 Firebase emulators 运行；locators 以真实 UI 为准，运行时可能要微调 */);

  testWidgets('J4 他人主页 —— Alice 看 Bob 应显示 TA 视角 + 更多菜单', (tester) async {
    await resetFirestore();

    // 先创建 Bob 账号拿 uid（用于 deep link），再登录 Alice
    final bob = await signInAndSeed(kTestUserBob);
    await signOutIfAny();
    await signInAndSeed(kTestUserAlice);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 导航到 Bob 的主页：通过 go_router deep link
    // 注意：此处依赖 app 暴露 router，或通过手动 context.go 实现；
    // 若不方便，也可从首页点 Bob 的帖子 → 头像 → profile
    // 这里先按 deep link 假设：需要 app 在 main 启动时支持 initialLocation
    expect(bob.uid, isNotEmpty); // sanity

    // expect(find.text('测试-Bob'), findsOneWidget);
    // expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    // expect(find.byIcon(Icons.edit_outlined), findsNothing);
  }, skip: true /* 需要 Firebase emulators 运行；deep link 钩子待补 */);
}
