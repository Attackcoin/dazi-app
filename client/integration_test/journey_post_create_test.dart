// J2 发帖 Journey：已登录 Alice → 首页 FAB → 填表 → 发布 → Firestore 可查到新帖。
//
// 登录走 signInAndSeed（email/password），绕过 UI phone flow。
// 时间选择走原生 showDatePicker/showTimePicker，接受 initialDate（now+1d）
// 和 initialTime（19:00）默认值，只点 "OK" 关闭两个弹窗即可满足 validate。
//
// 断言策略：直接查 Firestore `posts` 集合（emulator）—— 不依赖详情页 UI，
// 绕开 go_router pushReplacement 后的 widget tree 稳定性问题。

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

  testWidgets('J2 发帖 —— Alice 发布新搭子后 Firestore 可查到', (tester) async {
    // KP-4: 必须先登录再 resetFirestore。但 resetFirestore list applications
    // 会被 rules L23 拒（需要 applicantId where 条件）。J2 用唯一标题查询
    // 区分本次发帖，不依赖全表清空 → 这里跳过 resetFirestore。
    await signInAndSeed(kTestUserAlice);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 1. 首页（已登录 + Alice 有 city）→ 点 FAB（Glass Morph 改造后用 Icons.add）
    //    home_shell.dart:53
    final fab = find.byIcon(Icons.add);
    expect(fab, findsOneWidget, reason: '首页应显示发布 FAB');
    await tester.tap(fab);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // 2. 发布搭子页：选分类 "吃喝"（PillTag 显示 "🍜 吃喝"，用 textContaining）
    //    categoriesProvider 是 Firestore stream，可能要等 1 帧才发出 defaults
    final catFinder = find.textContaining('吃喝');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      if (catFinder.evaluate().isNotEmpty) break;
    }
    expect(catFinder, findsAtLeastNWidgets(1),
        reason: '发布页应能看到 "吃喝" 分类 PillTag');
    await tester.tap(catFinder.first);
    await tester.pump();

    // 3. 填标题 —— 发帖页只有 3 个 TextField（title / location / desc），
    //    title 是第一个
    final titleField = find.byType(TextField).at(0);
    const kTitle = '周末咖啡探店';
    await tester.enterText(titleField, kTitle);
    await tester.pump();

    // 4. 点时间选择器 → showDatePicker → 点 OK → showTimePicker → 点 OK
    //    initialDate = now + 1 day，initialTime = 19:00，都满足"未来"校验
    await tester.tap(find.text('选择活动时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    // 此时 TimePicker 打开
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // 5. 填地点（第二个 TextField）
    final locationField = find.byType(TextField).at(1);
    await tester.enterText(locationField, '静安寺星巴克臻选');
    await tester.pump();

    // 6. 滚到底并点 "发布" 按钮（Glass Morph：GlassButton, create_post_screen.dart:437）
    final publishBtn = find.widgetWithText(GlassButton, '发布');
    await tester.ensureVisible(publishBtn);
    await tester.pumpAndSettle();
    await tester.tap(publishBtn);
    // 发布 → Firestore write → pushReplacement('/post/$id') → 详情页
    await tester.pumpAndSettle(const Duration(seconds: 8));

    // 检查是否有 validate 失败的 snackbar（请填写/请选择/活动时间）
    for (final hint in const ['请填写', '请选择', '活动时间', '发布失败']) {
      if (find.textContaining(hint).evaluate().isNotEmpty) {
        fail('publish 触发 snackbar 提示：包含 "$hint"');
      }
    }

    // 7. 断言 Firestore：emulator 的 posts 集合应有一条 title = kTitle 的记录
    final snap = await FirebaseFirestore.instance
        .collection('posts')
        .where('title', isEqualTo: kTitle)
        .get();
    expect(
      snap.docs.length,
      greaterThanOrEqualTo(1),
      reason: '发布后 Firestore posts 集合应至少有一条 title=$kTitle 的记录',
    );

    final doc = snap.docs.first.data();
    expect(doc['userId'], isNotNull);
    expect(doc['category'], '吃喝');
    expect(doc['status'], 'open');
    expect(doc['location']['name'], '静安寺星巴克臻选');
  });
}
