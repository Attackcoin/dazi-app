// E2E 测试固定夹具：预置用户、帖子、申请等。
//
// 登录策略说明：
// - 项目主流程是手机号 + 验证码登录（Firebase Auth Phone）。但在 emulator 里模拟
//   phone code 回调需要 polling REST 端点，且回调通过 Streams/Completer 传递，
//   测试里容易竞态。
// - 因此 E2E 测试走 email/password 登录（emulator 支持，不影响产品代码），
//   通过 FirebaseAuth 生成 uid，再用该 uid 写 seed 数据。
// - 如果要端到端覆盖 phone 登录 UI 本身，使用 journey_login_test.dart（单独一个
//   journey），其他 journey 调用 signInAsTestUser 直接进入已登录态即可。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestUser {
  const TestUser({
    required this.slug,
    required this.phone,
    required this.name,
    required this.city,
    this.gender = 'male',
    this.birthYear = 1998,
  });

  /// slug 仅用于派生 email 和标识测试用户；真实 uid 由 Firebase Auth 生成，
  /// 调用 signInAsTestUser 后从 User.uid 读取。
  final String slug;
  final String phone;
  final String name;
  final String city;
  final String gender;
  final int birthYear;

  String get email => '$slug@test.local';
  static const String password = 'Test1234!';
}

/// 内置 3 个测试账号。
const kTestUserAlice = TestUser(
  slug: 'alice',
  phone: '+8613800000001',
  name: '测试-Alice',
  city: '上海',
  gender: 'female',
);
const kTestUserBob = TestUser(
  slug: 'bob',
  phone: '+8613800000002',
  name: '测试-Bob',
  city: '上海',
);
const kTestUserCarol = TestUser(
  slug: 'carol',
  phone: '+8613800000003',
  name: '测试-Carol',
  city: '北京',
  gender: 'female',
);

/// 清空测试相关集合。每个 journey 开头调用以保证隔离。
/// 注意：users 集合不在这里清——由 seedUser 覆盖写入即可。
Future<void> resetFirestore() async {
  final db = FirebaseFirestore.instance;
  for (final col in ['posts', 'applications', 'matches', 'reviews']) {
    final snap = await db.collection(col).get();
    for (final d in snap.docs) {
      await d.reference.delete();
    }
  }
}

/// 在 Auth emulator 里登录指定测试用户。
/// 首次调用会通过 createUserWithEmailAndPassword 创建账号，再次调用直接登录。
/// 返回真实 Firebase User（uid 由 Auth 生成，不等于 TestUser.slug）。
Future<User> signInAsTestUser(TestUser u) async {
  final auth = FirebaseAuth.instance;
  try {
    await auth.createUserWithEmailAndPassword(
      email: u.email,
      password: TestUser.password,
    );
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
  }
  final cred = await auth.signInWithEmailAndPassword(
    email: u.email,
    password: TestUser.password,
  );
  return cred.user!;
}

/// 登录 + 在 Firestore 写入对应的 users/{uid} 文档（如尚未存在）。
/// 大多数 journey 用这个入口：一行得到完整登录态。
///
/// 幂等：如果 users/{uid} 已存在则跳过（firestore.rules `users update` 规则
/// 只允许修改白名单字段，重写全量会被拒；且重跑时这些字段值已和预期一致）。
Future<User> signInAndSeed(TestUser u) async {
  final user = await signInAsTestUser(u);
  await _writeUserDocIfMissing(user.uid, u);
  return user;
}

Future<void> _writeUserDocIfMissing(String uid, TestUser u) async {
  final ref = FirebaseFirestore.instance.doc('users/$uid');
  final snap = await ref.get();
  if (snap.exists) {
    // 旧 seed 缺 birthYear（router redirect 用它判断 onboarding 完成）。
    // 补一次 update 让旧账号也跳过 onboarding。
    final data = snap.data();
    if (data == null || data['birthYear'] == null) {
      await ref.update({'birthYear': u.birthYear});
    }
    return;
  }

  // 字段严格按 firestore.rules `users create` 白名单（L12-27）：
  // 仅允许 keys: name,bio,avatar,city,gender,age,tags,fcmToken,
  //   sesameAuthorized,notificationSettings,rating,reviewCount,
  //   ratingSum,ratingCount,ghostCount,totalMeetups,badges,isRestricted,
  //   createdAt,updatedAt
  // 信誉/风控字段必须为默认值：
  //   rating==5.0, reviewCount==0, ratingSum==0, ratingCount==0,
  //   ghostCount==0, totalMeetups==0, badges.size()==0, isRestricted==false
  final age = DateTime.now().year - u.birthYear;
  await ref.set(<String, dynamic>{
    'name': u.name,
    'bio': '',
    'avatar': '',
    'city': u.city,
    'gender': u.gender,
    'age': age,
    'birthYear': u.birthYear,
    'tags': <String>[],
    'sesameAuthorized': false,
    'notificationSettings': <String, dynamic>{},
    'rating': 5.0,
    'reviewCount': 0,
    'ratingSum': 0,
    'ratingCount': 0,
    'ghostCount': 0,
    'totalMeetups': 0,
    'badges': <String>[],
    'isRestricted': false,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
