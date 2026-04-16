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
    apiKey: 'AIzaSyAUW1C-KZUMt96zc_jFcYucmJvrN-2pqq0',
    appId: '1:342997816903:android:3474db2ec185937389c362',
    messagingSenderId: '342997816903',
    projectId: 'dazi-prod-9c9d6',
    databaseURL: 'https://dazi-prod-9c9d6-default-rtdb.firebaseio.com',
    storageBucket: 'dazi-prod-9c9d6.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDlrq-B2q4KfQ3QRmJdpJLOO99O388nTDg',
    appId: '1:342997816903:ios:42fdfd58e6575ecc89c362',
    messagingSenderId: '342997816903',
    projectId: 'dazi-prod-9c9d6',
    databaseURL: 'https://dazi-prod-9c9d6-default-rtdb.firebaseio.com',
    storageBucket: 'dazi-prod-9c9d6.firebasestorage.app',
    iosClientId: '342997816903-dtbve2h5qi4gvqsuhrp6eft44sfsobca.apps.googleusercontent.com',
    iosBundleId: 'app.dazi.daziApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBpsm5A9joJw5GGIQTRcyhZaMpaIht_aMY',
    appId: '1:342997816903:web:3e207c3afd658ef989c362',
    messagingSenderId: '342997816903',
    projectId: 'dazi-prod-9c9d6',
    authDomain: 'dazi-prod-9c9d6.firebaseapp.com',
    databaseURL: 'https://dazi-prod-9c9d6-default-rtdb.firebaseio.com',
    storageBucket: 'dazi-prod-9c9d6.firebasestorage.app',
    measurementId: 'G-SZN7TVCCWJ',
  );

}