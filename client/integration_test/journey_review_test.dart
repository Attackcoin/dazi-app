// J7 submitReview Journey —— 验证 H-2 (toUserId 校验) + H-3 (事务化 ratingSum).
//
// 验证目标（T1 修复闭环）：
// - H-2：toUserId 必须是同 match 的其他参与者（防止污染任意用户评分）
//        - 非参与者 → permission-denied
//        - 自评（toUserId == fromUid）→ permission-denied
// - H-3：写入 review + 更新 users.ratingSum/ratingCount 必须同事务原子提交
//        - 子验证：复合 ID 防重 → already-exists
//        - 子验证：双方各评一次后，ratingSum/ratingCount 增量正确
//
// 策略：**不走 UI**（对齐 J5/J6）。submitReview 全在 Cloud Function 事务里。
// 直接调 callable + Firestore 断言。
//
// 难点：matches.status 只能由 Cloud Functions 写入（rules L98-101 限制
//       diff().affectedKeys() 只允许 lastMessageAt/lastMessagePreview）。
//       签到流程 J6 已覆盖；J7 直接 admin REST 把 match.status 强推 completed。
//
// 运行前置：
//   1. `firebase emulators:start --only auth,firestore,functions`
//   2. `chromedriver --port=4444 &`
//   3. `flutter drive --driver=test_driver/integration_test.dart \
//        --target=integration_test/journey_review_test.dart \
//        -d chrome --browser-name=chrome --dart-define=USE_EMULATOR=true`

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dazi_app/firebase_options.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/emulator_setup.dart';
import 'helpers/firestore_admin_helper.dart';
import 'helpers/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootTestFirebase();
  });

  tearDown(() async {
    await signOutIfAny();
  });

  testWidgets('J7 submitReview —— H-2 toUserId 校验 + H-3 事务化 ratingSum',
      (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final kTitle = 'J7评价测试_$suffix';
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

    // ──────────────────────────────────────────────
    // 1. 三方 seed：Alice 发帖，Bob 申请，Carol 作为非参与者用于 H-2 负样本
    // ──────────────────────────────────────────────
    final alice = await signInAndSeed(kTestUserAlice);
    final postRef = await FirebaseFirestore.instance.collection('posts').add({
      'userId': alice.uid,
      'title': kTitle,
      'description': 'J7 review 测试',
      'category': '吃喝',
      'time': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
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

    final bob = await signInAndSeed(kTestUserBob);
    final bobApply = await functions
        .httpsCallable('applyToPost')
        .call<Map<String, dynamic>>({'postId': postId, 'note': 'Bob'});
    final bobAppId = bobApply.data['applicationId'] as String;
    await signOutIfAny();

    // Carol 只 seed user 文档，不参与 match —— H-2 负样本要她的 uid
    final carol = await signInAndSeed(kTestUserCarol);
    final carolUid = carol.uid;
    await signOutIfAny();

    await signInAndSeed(kTestUserAlice);
    await functions
        .httpsCallable('acceptApplication')
        .call<Map<String, dynamic>>({'applicationId': bobAppId});

    final matchSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('participants', arrayContains: alice.uid)
        .where('postId', isEqualTo: postId)
        .get();
    expect(matchSnap.docs.length, 1);
    final matchId = matchSnap.docs.first.id;

    // ──────────────────────────────────────────────
    // 2. admin REST 强推 match.status='completed'
    //    —— J6 已覆盖签到 happy path，J7 不重复
    // ──────────────────────────────────────────────
    await adminPatchDoc(
      projectId: projectId,
      docPath: 'matches/$matchId',
      fields: {'status': encodeString('completed')},
    );

    // 记录 Alice / Bob 当前 ratingSum/Count，用作增量基线
    // （必须在 signOut 前读取，rules L8 要求 auth != null）
    final aliceBefore =
        await FirebaseFirestore.instance.doc('users/${alice.uid}').get();
    final bobBefore =
        await FirebaseFirestore.instance.doc('users/${bob.uid}').get();
    await signOutIfAny();
    final aliceSumBefore =
        (aliceBefore.data()?['ratingSum'] as num?)?.toInt() ?? 0;
    final aliceCountBefore =
        (aliceBefore.data()?['ratingCount'] as num?)?.toInt() ?? 0;
    final bobSumBefore =
        (bobBefore.data()?['ratingSum'] as num?)?.toInt() ?? 0;
    final bobCountBefore =
        (bobBefore.data()?['ratingCount'] as num?)?.toInt() ?? 0;

    // ──────────────────────────────────────────────
    // 3. Bob 登录 —— H-2 负样本 #1: toUserId = Carol（非参与者）
    // ──────────────────────────────────────────────
    await signInAndSeed(kTestUserBob);
    try {
      await functions
          .httpsCallable('submitReview')
          .call<Map<dynamic, dynamic>>({
        'matchId': matchId,
        'toUserId': carolUid,
        'rating': 5,
      });
      fail('toUserId 非参与者应抛 permission-denied');
    } on FirebaseFunctionsException catch (e) {
      expect(e.code, 'permission-denied',
          reason: 'H-2：toUserId=非参与者 → permission-denied');
    }

    // ──────────────────────────────────────────────
    // 4. H-2 负样本 #2: toUserId = 自己（self-review）
    // ──────────────────────────────────────────────
    try {
      await functions
          .httpsCallable('submitReview')
          .call<Map<dynamic, dynamic>>({
        'matchId': matchId,
        'toUserId': bob.uid,
        'rating': 5,
      });
      fail('自评应抛 permission-denied');
    } on FirebaseFunctionsException catch (e) {
      expect(e.code, 'permission-denied',
          reason: 'H-2：自评 → permission-denied');
    }

    // ──────────────────────────────────────────────
    // 5. H-3 happy: Bob 评 Alice 5 星 → review 写入 + alice.ratingSum +5
    // ──────────────────────────────────────────────
    final bobReview = await functions
        .httpsCallable('submitReview')
        .call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      'toUserId': alice.uid,
      'rating': 5,
      'comment': 'Bob 评 Alice',
      'tags': <String>['友善', '准时'],
    });
    expect(bobReview.data['success'], isTrue);

    // 验证复合 ID + 字段
    final bobReviewDoc = await FirebaseFirestore.instance
        .doc('reviews/${matchId}_${bob.uid}_${alice.uid}')
        .get();
    expect(bobReviewDoc.exists, isTrue, reason: 'H-3：review 文档应已写入');
    expect(bobReviewDoc.data()?['fromUser'], bob.uid);
    expect(bobReviewDoc.data()?['toUser'], alice.uid);
    expect(bobReviewDoc.data()?['rating'], 5);

    // ──────────────────────────────────────────────
    // 6. H-3 幂等：Bob 重复评价 → already-exists（同事务 CAS 守门）
    // ──────────────────────────────────────────────
    try {
      await functions
          .httpsCallable('submitReview')
          .call<Map<dynamic, dynamic>>({
        'matchId': matchId,
        'toUserId': alice.uid,
        'rating': 4,
      });
      fail('重复评价应抛 already-exists');
    } on FirebaseFunctionsException catch (e) {
      expect(e.code, 'already-exists',
          reason: 'H-3：复合 ID 守住重复评价');
    }
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 7. Alice 评 Bob 4 星 → bob.ratingSum +4
    // ──────────────────────────────────────────────
    await signInAndSeed(kTestUserAlice);
    final aliceReview = await functions
        .httpsCallable('submitReview')
        .call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      'toUserId': bob.uid,
      'rating': 4,
      'comment': 'Alice 评 Bob',
      'tags': <String>[],
    });
    expect(aliceReview.data['success'], isTrue);

    // ──────────────────────────────────────────────
    // 8. 终态断言：双方 ratingSum/Count 原子增量正确
    //    （必须在 signOut 前读取，rules L8 要求 auth != null）
    // ──────────────────────────────────────────────
    final aliceAfter =
        await FirebaseFirestore.instance.doc('users/${alice.uid}').get();
    final bobAfter =
        await FirebaseFirestore.instance.doc('users/${bob.uid}').get();
    await signOutIfAny();

    expect(
      (aliceAfter.data()?['ratingSum'] as num).toInt(),
      aliceSumBefore + 5,
      reason: 'H-3：Alice ratingSum 应增 5（Bob 评 5 星）',
    );
    expect(
      (aliceAfter.data()?['ratingCount'] as num).toInt(),
      aliceCountBefore + 1,
      reason: 'H-3：Alice ratingCount 应 +1',
    );
    expect(
      (bobAfter.data()?['ratingSum'] as num).toInt(),
      bobSumBefore + 4,
      reason: 'H-3：Bob ratingSum 应增 4（Alice 评 4 星）',
    );
    expect(
      (bobAfter.data()?['ratingCount'] as num).toInt(),
      bobCountBefore + 1,
      reason: 'H-3：Bob ratingCount 应 +1',
    );
  });
}
