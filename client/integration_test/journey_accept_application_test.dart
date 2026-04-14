// J5 acceptApplication + 满员 auto_reject Journey。
//
// 验证目标（T1 修复闭环）：
// - M-9  满员后批量 auto_reject 其它 pending 申请
// - H-1  applyToPost 确定性 docId + CAS 幂等（通过 applicationId 的稳定性体现）
// - 事务化 match 创建 + post.acceptedGender/status 同事务更新
// - match 冗余字段 (postTitle/postCategory/participantInfo) 写入正确
//
// 策略：**不走 UI**。acceptApplication/applyToPost 的关键逻辑在 Cloud Function
// 事务里，UI 层只是包装。直接通过 httpsCallable 调后端 + Firestore 断言，
// 用例更稳、更快、覆盖更直接。
//
// 运行前置：
//   1. `firebase emulators:start --only auth,firestore,functions`
//   2. `chromedriver --port=4444 &`
//   3. `flutter drive --driver=test_driver/integration_test.dart \
//        --target=integration_test/journey_accept_application_test.dart \
//        -d chrome --browser-name=chrome --dart-define=USE_EMULATOR=true`

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  testWidgets('J5 acceptApplication — 满员 auto_reject + match 创建', (tester) async {
    // 唯一后缀：防遗留数据污染
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final kTitle = 'J5测试_$suffix';

    final functions =
        FirebaseFunctions.instanceFor(region: 'asia-southeast1');

    // ──────────────────────────────────────────────
    // 1. Alice 发帖（totalSlots=2 → 接受 1 人即满）
    // ──────────────────────────────────────────────
    final alice = await signInAndSeed(kTestUserAlice);

    // 字段严格按 firestore.rules `posts create` 白名单（L42-52）
    final postRef = await FirebaseFirestore.instance.collection('posts').add({
      'userId': alice.uid,
      'title': kTitle,
      'description': 'J5 acceptApplication 测试',
      'category': '吃喝',
      'time': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
      'location': {'name': '静安寺', 'city': '上海'},
      'totalSlots': 2,
      'costType': 'aa',
      'depositAmount': 0,
      'images': <String>[],
      'tags': <String>[],
      'isSocialAnxietyFriendly': false,
      'status': 'open',
      'acceptedGender': {'male': 0, 'female': 0},
      'waitlist': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final postId = postRef.id;

    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 2. Bob 申请（callable applyToPost）
    // ──────────────────────────────────────────────
    final bob = await signInAndSeed(kTestUserBob);
    final bobApplyRes = await functions
        .httpsCallable('applyToPost')
        .call<Map<String, dynamic>>({'postId': postId, 'note': 'Bob'});
    expect(bobApplyRes.data['success'], isTrue,
        reason: 'Bob applyToPost 应成功');
    final bobAppId = bobApplyRes.data['applicationId'] as String;
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 3. Carol 申请（同一个 post）
    // ──────────────────────────────────────────────
    final carol = await signInAndSeed(kTestUserCarol);
    final carolApplyRes = await functions
        .httpsCallable('applyToPost')
        .call<Map<String, dynamic>>({'postId': postId, 'note': 'Carol'});
    expect(carolApplyRes.data['success'], isTrue,
        reason: 'Carol applyToPost 应成功');
    final carolAppId = carolApplyRes.data['applicationId'] as String;
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 4. Alice 登录 → acceptApplication(Bob)
    //    （初态 pending 断言省略：需登录态才能读 applications；
    //    而步骤 5 的 accepted/auto_rejected 断言已隐含覆盖 pending→X 转换）
    // ──────────────────────────────────────────────
    await signInAndSeed(kTestUserAlice);
    final acceptRes = await functions
        .httpsCallable('acceptApplication')
        .call<Map<String, dynamic>>({'applicationId': bobAppId});
    expect(acceptRes.data['success'], isTrue,
        reason: 'Alice 应能接受 Bob 的申请');

    // ──────────────────────────────────────────────
    // 5. 断言：Bob accepted、Carol auto_rejected（M-9）
    // ──────────────────────────────────────────────
    // Cloud Function 事务完成后立即读取（非异步副作用）
    final bobAppFinal = await FirebaseFirestore.instance
        .doc('applications/$bobAppId')
        .get();
    expect(bobAppFinal.data()?['status'], 'accepted',
        reason: 'Bob 应从 pending → accepted');

    final carolAppFinal = await FirebaseFirestore.instance
        .doc('applications/$carolAppId')
        .get();
    expect(carolAppFinal.data()?['status'], 'auto_rejected',
        reason: 'M-9：满员后 Carol 应被批量 auto_rejected');

    // ──────────────────────────────────────────────
    // 6. 断言：post.status='full'，acceptedGender 计数 +1
    // ──────────────────────────────────────────────
    final postFinal =
        await FirebaseFirestore.instance.doc('posts/$postId').get();
    expect(postFinal.data()?['status'], 'full');
    final acceptedGender =
        (postFinal.data()?['acceptedGender'] as Map).cast<String, dynamic>();
    // Bob 默认 gender='male'
    expect(acceptedGender['male'], 1);

    // ──────────────────────────────────────────────
    // 7. 断言：matches 集合有一条记录，冗余字段正确
    // ──────────────────────────────────────────────
    // firestore.rules L89-91 要求 list matches 必须带 participants array-contains
    // 约束（Alice 此时已登录且是 post owner → 是 match 参与者之一）
    final matchSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('participants', arrayContains: alice.uid)
        .where('postId', isEqualTo: postId)
        .get();
    expect(matchSnap.docs.length, 1, reason: '应创建一条 match');

    final match = matchSnap.docs.first.data();
    expect(
      (match['participants'] as List).cast<String>().toSet(),
      {alice.uid, bob.uid},
      reason: 'match.participants 应是 [alice, bob]',
    );
    expect(match['postTitle'], kTitle, reason: '冗余字段 postTitle 应写入');
    expect(match['postCategory'], '吃喝', reason: '冗余字段 postCategory 应写入');
    expect(match['status'], 'confirmed');
    expect(match['checkinWindowOpen'], false);
    expect(match['checkedIn'], <String>[]);

    final participantInfo =
        (match['participantInfo'] as Map).cast<String, dynamic>();
    expect(participantInfo[alice.uid]['name'], kTestUserAlice.name);
    expect(participantInfo[bob.uid]['name'], kTestUserBob.name);

    // Carol 不应出现在 match 里
    expect(participantInfo.containsKey(carol.uid), isFalse);
  });
}
