// J6 submitCheckin Journey —— 验证 H-4 (CAS) + M-1 (GPS).
//
// 验证目标（T1 修复闭环）：
// - M-1：post 保存了 location.lat/lng 时，submitCheckin 必须收到 lat/lng；
//        且距离活动地点必须 ≤ 500m，否则 out-of-range
// - H-4：runTransaction 内 CAS 推进 match.status —— 最后一人签到 →
//        match.status='completed' + post.status='done' + 双方 totalMeetups+1
//
// 策略：**不走 UI**（对齐 J5）。submitCheckin 关键逻辑全在 Cloud Function
// 事务里。直接调 callable + Firestore 断言。
//
// 难点：matches.checkinWindowOpen 只能由 Cloud Functions 写入（rules L98-101），
//       且唯一开启时机是 onCheckinTimeout cron（5min 间隔）。E2E 走 admin REST
//       绕过 rules 直接 patch 该字段。
//
// 运行前置：
//   1. `firebase emulators:start --only auth,firestore,functions`
//   2. `chromedriver --port=4444 &`
//   3. `flutter drive --driver=test_driver/integration_test.dart \
//        --target=integration_test/journey_checkin_test.dart \
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

  testWidgets('J6 submitCheckin —— M-1 GPS 校验 + H-4 最后一人 CAS 完成',
      (tester) async {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    final kTitle = 'J6签到测试_$suffix';
    final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
    final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

    // 静安寺真实坐标（活动地点）
    const postLat = 31.2235;
    const postLng = 121.4456;
    // ~200m 外（在 500m 半径内，签到通过）
    const nearLat = 31.2253;
    const nearLng = 121.4456;
    // ~5km 外（远超 500m，签到拒绝）
    const farLat = 31.2700;
    const farLng = 121.4456;

    // ──────────────────────────────────────────────
    // 1. Alice 发帖 —— location 含 lat/lng 触发 M-1 校验路径
    // ──────────────────────────────────────────────
    final alice = await signInAndSeed(kTestUserAlice);
    final postRef = await FirebaseFirestore.instance.collection('posts').add({
      'userId': alice.uid,
      'title': kTitle,
      'description': 'J6 checkin 测试',
      'category': '吃喝',
      'time': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
      'location': {
        'name': '静安寺',
        'city': '上海',
        'lat': postLat,
        'lng': postLng,
      },
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
    // 2. Bob 申请
    // ──────────────────────────────────────────────
    final bob = await signInAndSeed(kTestUserBob);
    final bobApply = await functions
        .httpsCallable('applyToPost')
        .call<Map<String, dynamic>>({'postId': postId, 'note': 'Bob'});
    expect(bobApply.data['success'], isTrue);
    final bobAppId = bobApply.data['applicationId'] as String;
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 3. Alice 接受 → match 创建
    // ──────────────────────────────────────────────
    await signInAndSeed(kTestUserAlice);
    final acceptRes = await functions
        .httpsCallable('acceptApplication')
        .call<Map<String, dynamic>>({'applicationId': bobAppId});
    expect(acceptRes.data['success'], isTrue);

    final matchSnap = await FirebaseFirestore.instance
        .collection('matches')
        .where('participants', arrayContains: alice.uid)
        .where('postId', isEqualTo: postId)
        .get();
    expect(matchSnap.docs.length, 1);
    final matchId = matchSnap.docs.first.id;

    // ──────────────────────────────────────────────
    // 4. admin REST 强行打开签到窗口（rules L98-101 拒绝客户端写）
    //    + 设 expiresAt 为未来 1 小时，避免 onCheckinTimeout cron 把它判超时
    // ──────────────────────────────────────────────
    final expiresAt = DateTime.now().add(const Duration(hours: 1));
    await adminPatchDoc(
      projectId: projectId,
      docPath: 'matches/$matchId',
      fields: {
        'checkinWindowOpen': encodeBool(true),
        'checkinWindowExpiresAt': encodeTimestamp(expiresAt),
      },
    );
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 5. M-1 负样本 #1：Bob 不传坐标 → invalid-argument
    // ──────────────────────────────────────────────
    await signInAndSeed(kTestUserBob);
    try {
      await functions
          .httpsCallable('submitCheckin')
          .call<Map<dynamic, dynamic>>({'matchId': matchId});
      fail('未传 lat/lng 应抛 invalid-argument');
    } on FirebaseFunctionsException catch (e) {
      expect(e.code, 'invalid-argument',
          reason: 'M-1：post 有坐标但客户端不传 → invalid-argument');
    }

    // ──────────────────────────────────────────────
    // 6. M-1 负样本 #2：Bob 远距离 → out-of-range
    // ──────────────────────────────────────────────
    try {
      await functions
          .httpsCallable('submitCheckin')
          .call<Map<dynamic, dynamic>>({
        'matchId': matchId,
        'lat': farLat,
        'lng': farLng,
      });
      fail('5km 外应抛 out-of-range');
    } on FirebaseFunctionsException catch (e) {
      expect(e.code, 'out-of-range',
          reason: 'M-1：超过 500m 半径 → out-of-range');
    }

    // ──────────────────────────────────────────────
    // 7. M-1 happy：Bob 近距离签到成功（match 还未完成）
    // ──────────────────────────────────────────────
    final bobCheckin = await functions
        .httpsCallable('submitCheckin')
        .call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      'lat': nearLat,
      'lng': nearLng,
    });
    expect(bobCheckin.data['success'], isTrue);
    expect(bobCheckin.data['allCheckedIn'], isFalse,
        reason: '只有 Bob 签到，allCheckedIn 应为 false');

    // 中间断言：match.checkedIn 含 Bob，status 仍 confirmed
    final midMatch = await FirebaseFirestore.instance
        .doc('matches/$matchId')
        .get();
    expect((midMatch.data()?['checkedIn'] as List).cast<String>(), [bob.uid]);
    expect(midMatch.data()?['status'], 'confirmed');

    // H-4 幂等性子验证：Bob 重复签到 → already-exists（同事务 CAS 守门）
    try {
      await functions
          .httpsCallable('submitCheckin')
          .call<Map<dynamic, dynamic>>({
        'matchId': matchId,
        'lat': nearLat,
        'lng': nearLng,
      });
      fail('重复签到应抛 already-exists');
    } on FirebaseFunctionsException catch (e) {
      expect(e.code, 'already-exists',
          reason: 'H-4：CAS 守住重复签到，第二次应 already-exists');
    }
    await signOutIfAny();

    // ──────────────────────────────────────────────
    // 8. H-4 关键路径：Alice 签到 → match.status 原子推进 completed
    // ──────────────────────────────────────────────
    await signInAndSeed(kTestUserAlice);
    final aliceCheckin = await functions
        .httpsCallable('submitCheckin')
        .call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      'lat': nearLat,
      'lng': nearLng,
    });
    expect(aliceCheckin.data['allCheckedIn'], isTrue,
        reason: 'H-4：最后一人签到，allCheckedIn 应翻 true');

    // ──────────────────────────────────────────────
    // 9. 终态断言（事务内副作用）
    //    - match.status='completed' / checkinWindowOpen=false / completedAt 写入
    //    - post.status='done'
    //    - 双方 users.totalMeetups +1
    // ──────────────────────────────────────────────
    final finalMatch =
        await FirebaseFirestore.instance.doc('matches/$matchId').get();
    expect(finalMatch.data()?['status'], 'completed',
        reason: 'H-4：match 应翻 completed');
    expect(finalMatch.data()?['checkinWindowOpen'], isFalse);
    expect(finalMatch.data()?['completedAt'], isNotNull);
    expect(
      (finalMatch.data()?['checkedIn'] as List).cast<String>().toSet(),
      {alice.uid, bob.uid},
    );

    final finalPost =
        await FirebaseFirestore.instance.doc('posts/$postId').get();
    expect(finalPost.data()?['status'], 'done',
        reason: 'H-4：post 同事务推进到 done');

    final aliceUser =
        await FirebaseFirestore.instance.doc('users/${alice.uid}').get();
    final bobUser =
        await FirebaseFirestore.instance.doc('users/${bob.uid}').get();
    expect((aliceUser.data()?['totalMeetups'] as num?)?.toInt() ?? 0,
        greaterThanOrEqualTo(1),
        reason: 'H-4：Alice totalMeetups 应 +1');
    expect((bobUser.data()?['totalMeetups'] as num?)?.toInt() ?? 0,
        greaterThanOrEqualTo(1),
        reason: 'H-4：Bob totalMeetups 应 +1');
  });
}
