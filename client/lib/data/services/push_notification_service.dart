import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';

final firebaseMessagingProvider =
    Provider<FirebaseMessaging>((_) => FirebaseMessaging.instance);

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(
    messaging: ref.watch(firebaseMessagingProvider),
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// FCM 推送通知服务 —— 请求权限、获取 token、保存到 Firestore。
class PushNotificationService {
  PushNotificationService({
    required FirebaseMessaging messaging,
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _messaging = messaging,
        _firestore = firestore,
        _auth = auth;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 初始化推送：请求权限 → 获取 token → 保存到用户文档。
  Future<void> initialize() async {
    // Web 平台需要 VAPID key，暂时跳过
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      debugPrint('FCM: 用户拒绝了推送权限');
      return;
    }

    // 获取并保存 token
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // 监听 token 刷新
    _messaging.onTokenRefresh.listen(_saveToken);

    // 前台消息处理
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 点击通知打开 App 时的处理
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 检查是否从通知冷启动
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// 把 FCM token 保存到当前用户的 Firestore 文档。
  Future<void> _saveToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('FCM: token 已保存');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM 前台消息: ${message.notification?.title}');
    // 前台时不弹系统通知（避免干扰当前页面），
    // 可以用 SnackBar 或 in-app banner 展示。
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('FCM 点击通知: ${message.data}');
    // 根据 data 中的 type/chatId/postId 等字段跳转到对应页面。
    // 路由跳转需要 navigatorKey，后续可通过全局 GoRouter 实现。
  }
}
