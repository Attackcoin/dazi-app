// 由 `flutterfire configure --project=dazi-dev` 生成（2026-04-09）。
// 如需重新生成，在 `client/` 目录下再跑一次该命令即可。
// DO NOT edit manually —— 任何手工修改在下次 flutterfire configure 时会被覆盖。

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB-PDiMcBarNdxtWzdejnOqdfWoej-POp0',
    appId: '1:768282971908:android:4ce4e2bb4ed21fae6dca51',
    messagingSenderId: '768282971908',
    projectId: 'dazi-dev',
    databaseURL: 'https://dazi-dev-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dazi-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBy0ENmvseDJf7AabIvhFpXSRk1rOC9leQ',
    appId: '1:768282971908:ios:b2cf603a86c7c0ee6dca51',
    messagingSenderId: '768282971908',
    projectId: 'dazi-dev',
    databaseURL: 'https://dazi-dev-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dazi-dev.firebasestorage.app',
    iosClientId: '768282971908-k9mv26j3qor01ugd2l8dk9rsrv9gitd2.apps.googleusercontent.com',
    iosBundleId: 'app.dazi.daziApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDd1TNNA9-l-lDFfL4fqQkHzJ6NJ2d_wGQ',
    appId: '1:768282971908:web:2f027e1fe19b35aa6dca51',
    messagingSenderId: '768282971908',
    projectId: 'dazi-dev',
    authDomain: 'dazi-dev.firebaseapp.com',
    databaseURL: 'https://dazi-dev-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'dazi-dev.firebasestorage.app',
    measurementId: 'G-TC2H1EJVHS',
  );

}