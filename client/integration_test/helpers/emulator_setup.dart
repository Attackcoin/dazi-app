// E2E 测试用 Firebase Emulator 接入 helper。
//
// 用法：每个 integration_test 的 `setUpAll` 里 `await bootTestFirebase();`
//
// 先决条件：
//   1. 本项目根目录执行 `firebase emulators:start`
//   2. firebase_options.dart 已由 flutterfire configure 生成（T1a 完成）
//   3. 运行命令：
//        cd client
//        flutter test integration_test/ --dart-define=USE_FIREBASE_EMULATOR=true
//
// 说明：
// - 本文件不依赖真实 Firebase 项目，只要求 firebase_options.dart 可编译通过
//   （占位文件只要保持 class 结构就能让 test 二进制打包成功）。
// - 通过 `useFirestoreEmulator` / `useAuthEmulator` / ... 把 SDK 指向本地。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:dazi_app/firebase_options.dart';

/// 与 firebase.json 中的端口对齐。
const _host = '127.0.0.1';
const _authPort = 9099;
const _firestorePort = 8080;
const _functionsPort = 5001;
const _databasePort = 9000;
const _storagePort = 9199;

bool _initialized = false;

/// 初始化 Firebase + 把所有 SDK 指向本地 emulator。
/// 重复调用无副作用。
Future<void> bootTestFirebase() async {
  if (_initialized) return;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Auth —— 必须在调用任何 auth 方法前设置
  await FirebaseAuth.instance.useAuthEmulator(_host, _authPort);

  // Firestore
  FirebaseFirestore.instance.useFirestoreEmulator(_host, _firestorePort);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    sslEnabled: false,
  );

  // Functions —— 区域必须与后端一致（已统一 asia-southeast1）
  FirebaseFunctions.instanceFor(region: 'asia-southeast1')
      .useFunctionsEmulator(_host, _functionsPort);

  // Storage
  await FirebaseStorage.instance.useStorageEmulator(_host, _storagePort);

  // RTDB
  FirebaseDatabase.instance.useDatabaseEmulator(_host, _databasePort);

  _initialized = true;
}

/// 清理 Auth 状态（每个 journey 之间调用，避免上一 journey 的登录态泄漏）。
Future<void> signOutIfAny() async {
  if (FirebaseAuth.instance.currentUser != null) {
    await FirebaseAuth.instance.signOut();
  }
}
