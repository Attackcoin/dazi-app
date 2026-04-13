// J1 登录 Journey：手机号 → 验证码 → 首页/onboarding。
//
// 这个 journey 专门覆盖 phone code UI 流程本身。其他 journey 应走 email/password
// 的 signInAndSeed 快速通道，不再依赖此 journey。
//
// 运行前置：
//   1. firebase emulators:start （Auth 必须启动）
//   2. Auth emulator 默认为测试手机号返回固定 code，需要先在 Firebase Console
//      或通过 REST POST /identitytoolkit.googleapis.com/v1/projects/{id}/accounts
//      为 phone `+8613800000001` 预置 verification code `123456`。
//      简便做法：在 setUpAll 里通过 HTTP 调用 emulator 的
//      `/emulator/v1/projects/{id}/verificationCodes` GET 来读当前生成的 code。
//   3. flutter test integration_test/journey_login_test.dart --dart-define=USE_FIREBASE_EMULATOR=true

import 'package:dazi_app/firebase_options.dart';
import 'package:dazi_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/emulator_setup.dart';
import 'helpers/sms_code_helper.dart';
import 'helpers/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootTestFirebase();
  });

  tearDown(() async {
    await signOutIfAny();
  });

  testWidgets('J1 手机号登录 —— Alice 输入手机号 → 验证码 → 进入应用',
      (tester) async {
    // 注意：不调 resetFirestore() —— 未登录态下 firestore rules 拒绝 list。
    // J1 只覆盖登录 UI，不依赖 posts/applications 等集合的初态。

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 1. 登录页：输入 11 位手机号（去掉 +86 前缀）
    final localPhone = kTestUserAlice.phone.replaceFirst('+86', '');
    final phoneField = find.byType(TextField).first;
    await tester.enterText(phoneField, localPhone);
    await tester.pump();

    // 2. 勾选用户协议 checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    // 3. 点"获取验证码"
    await tester.tap(find.widgetWithText(ElevatedButton, '获取验证码'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 4. 从 Auth emulator REST 读取最新 verification code（emulator 不发真短信）
    //    轮询几次以规避 sendPhoneCode → emulator 内部写入的时序差
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    String? code;
    for (var i = 0; i < 10; i++) {
      try {
        code = await fetchLatestSmsCode(projectId, kTestUserAlice.phone);
        break;
      } on StateError {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      }
    }
    if (code == null) {
      throw StateError(
        '在 5s 内未从 emulator 读到 ${kTestUserAlice.phone} 的 verification code',
      );
    }

    final codeField = find.byType(TextField).first;
    await tester.enterText(codeField, code);
    await tester.pump();
    // 输入满 6 位会自动 submit（phone_verify_screen.dart:94）；
    // 保险起见也点一下"验证并登录"按钮
    final submit = find.widgetWithText(ElevatedButton, '验证并登录');
    if (submit.evaluate().isNotEmpty) {
      await tester.tap(submit);
    }
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 5. 应跳离登录页——要么进入 onboarding（首次登录无资料），要么进入首页
    final onLogin = find.text('获取验证码').evaluate().isNotEmpty;
    expect(onLogin, isFalse, reason: '登录后不应停留在登录页');
  });
}
