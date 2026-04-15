// J3 浏览+申请 Journey：Bob 浏览信息流 → 点 Alice 的帖子 → 申请加入。
//
// 策略：
// - **不调 resetFirestore()**：KP-4 已知 applications/matches/reviews 即使登录态
//   list 也被 rules 拒。改走"唯一标题幂等"策略（同 J2）：用随机后缀标题，Bob 的
//   申请断言用 `where postId==<唯一 post id>` 过滤，与遗留数据隔离。
// - Alice 不走 UI 发帖（J2 已验证过），直接 signIn → Firestore 写 posts doc（rules
//   允许登录态 create）→ signOut，加快 E2E。
// - Bob 走完整 UI：启动 → 首页 feed → 点卡片 → 详情页"立即申请" → ApplySheet
//   "确认申请" → polling 等 Cloud Function `applyToPost` 写入 applications。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dazi_app/core/widgets/glass_button.dart';
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

  testWidgets('J3 浏览并申请 —— Bob 可见 Alice 的帖并成功申请', (tester) async {
    // 唯一标题：防止遗留数据干扰 + 方便 Firestore 断言精确查询
    final kTitle = 'J3探店_${DateTime.now().millisecondsSinceEpoch}';

    // ──────────────────────────────────────────────
    // 1. Alice 登录并直写一条 post（绕 UI 发帖，速度快）
    // ──────────────────────────────────────────────
    final alice = await signInAndSeed(kTestUserAlice);

    // 字段严格按 firestore.rules posts create 白名单 L42-49
    // （minSlots/isInstant 不在白名单，必须移除；tags/updatedAt 保留）
    final postRef = await FirebaseFirestore.instance.collection('posts').add({
      'userId': alice.uid,
      'category': '吃喝',
      'title': kTitle,
      'description': '静安寺附近新开的咖啡馆',
      'images': <String>[],
      'tags': <String>[],
      'time': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
      'location': {'name': '静安寺', 'city': '上海'},
      'totalSlots': 4,
      // 注意：acceptedGender 存在 & 和 < totalSlots-1 → 走 pending 分支而不是候补
      'acceptedGender': {'male': 0, 'female': 0},
      'costType': 'aa',
      'depositAmount': 0,
      'isSocialAnxietyFriendly': false,
      'waitlist': <String>[],
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final postId = postRef.id;

    // 切换账号：sign out Alice
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 2. Bob 登录 + 启动 app
    // ──────────────────────────────────────────────
    final bob = await signInAndSeed(kTestUserBob);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ──────────────────────────────────────────────
    // 3. 默认 tab 是"滑一滑"(swipe)；J3 测 PostCard 列表，切到"发现"tab
    //    （Glass Morph 改版后，post list 在 /discover 而非 / — home_shell L87-93）
    // ──────────────────────────────────────────────
    final discoverTab =
        find.widgetWithText(InkWell, '发现').hitTestable();
    if (discoverTab.evaluate().isNotEmpty) {
      await tester.tap(discoverTab.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // 4. 首页 feed 应出现 Alice 的帖子（Bob 和 Alice 同城：上海）
    final titleFinder = find.text(kTitle);

    // 轻量 polling：等 Firestore stream 把新 doc 推下来 + PostCard build
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (titleFinder.evaluate().isNotEmpty) break;
    }
    expect(titleFinder, findsOneWidget,
        reason: '首页 feed 应出现 Alice 新发的帖（title=$kTitle）');

    // ──────────────────────────────────────────────
    // 4. 点卡片 → 进详情页
    // ──────────────────────────────────────────────
    await tester.tap(titleFinder);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ──────────────────────────────────────────────
    // 5. 点"立即申请"（详情页 _ApplicantButtons，status=open 且未满）
    // ──────────────────────────────────────────────
    // Glass Morph 改造后改为 GlassButton（post_detail_screen.dart:438）
    final applyBtnFinder =
        find.widgetWithText(GlassButton, '立即申请');
    expect(applyBtnFinder, findsOneWidget,
        reason: '详情页应出现"立即申请"主按钮（post.status=open 且未满）');
    await tester.tap(applyBtnFinder);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // ──────────────────────────────────────────────
    // 6. ApplySheet 弹出 → 点"确认申请"
    // ──────────────────────────────────────────────
    final confirmBtnFinder =
        find.widgetWithText(ElevatedButton, '确认申请');
    expect(confirmBtnFinder, findsOneWidget,
        reason: 'ApplySheet 应弹出且主按钮文字为"确认申请"');
    await tester.tap(confirmBtnFinder);
    // Cloud Function 往返 + Firestore 写入，给足时间
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // ──────────────────────────────────────────────
    // 7. 断言 Firestore applications 里有 Bob 对该 post 的申请
    //   —— 用 postId 过滤，保证仅匹配本次 E2E 产生的数据
    //   —— polling 等 Function 异步写入完成
    // ──────────────────────────────────────────────
    QuerySnapshot<Map<String, dynamic>>? snap;
    for (var i = 0; i < 10; i++) {
      snap = await FirebaseFirestore.instance
          .collection('applications')
          .where('postId', isEqualTo: postId)
          .where('applicantId', isEqualTo: bob.uid)
          .get();
      if (snap.docs.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(snap, isNotNull);
    expect(snap!.docs.length, greaterThanOrEqualTo(1),
        reason: 'applications 集合应有 Bob 对该 post 的一条记录');

    final appDoc = snap.docs.first.data();
    expect(appDoc['postId'], postId);
    expect(appDoc['applicantId'], bob.uid);
    expect(appDoc['status'], anyOf('pending', 'waitlisted'));
  });
}
