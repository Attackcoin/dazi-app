// 占位文件 — 运行前必须替换
//
// 生成真实的 firebase_options.dart：
//   1. 安装 FlutterFire CLI: `dart pub global activate flutterfire_cli`
//   2. 登录 Firebase: `firebase login`
//   3. 进入项目目录: `cd client`
//   4. 运行: `flutterfire configure --project=dazi-dev`
//   5. 选择 iOS + Android 平台
// 该命令会自动生成真实的 firebase_options.dart 并覆盖此文件。
//
// 参考: https://firebase.google.com/docs/flutter/setup

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台暂未配置，请运行 flutterfire configure');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          '当前平台未配置 Firebase，请运行 flutterfire configure',
        );
    }
  }

  // ⚠️ 占位值 — 运行 flutterfire configure 后会自动覆盖
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PLACEHOLDER_ANDROID_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'dazi-dev',
    storageBucket: 'dazi-dev.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_IOS_API_KEY',
    appId: 'PLACEHOLDER_APP_ID',
    messagingSenderId: 'PLACEHOLDER_SENDER_ID',
    projectId: 'dazi-dev',
    storageBucket: 'dazi-dev.appspot.com',
    iosBundleId: 'app.dazi.daziApp',
  );
}
