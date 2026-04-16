import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/crashlytics_service.dart';
import 'firebase_options.dart';

const bool useFirebaseEmulator = bool.fromEnvironment('USE_EMULATOR');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // intl: 加载 zh_CN locale 数据（swipe_screen DateFormat('M月d日 EEE HH:mm', 'zh_CN')
  // 等需要；不 init 会在 render 时抛 LocaleDataException）
  await initializeDateFormatting('zh_CN');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initCrashlytics();
  if (useFirebaseEmulator) {
    final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
        ? '10.0.2.2'
        : '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
  runApp(const ProviderScope(child: DaziApp()));
}
