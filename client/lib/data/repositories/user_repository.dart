import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// 按 uid 订阅任意用户（含自己和他人）的只读 stream。
/// profile 页用这个而非 currentAppUserProvider，以支持"他人主页"视角。
final userByIdProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

/// 用户资料更新 —— 直接写 Firestore `users/{uid}`。
///
/// 安全规则应允许用户写自己的文档（部分字段除外，如 rating/ghostCount）。
class UserRepository {
  UserRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('未登录');
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> get _myDoc =>
      _firestore.collection('users').doc(_uid);

  /// 按 uid 只读订阅一个用户文档。用于 profile 页展示自己或他人。
  Stream<AppUser?> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? AppUser.fromFirestore(snap) : null);
  }

  /// 合并更新任意白名单字段。
  Future<void> updateProfile(Map<String, dynamic> patch) {
    return _myDoc.set(patch, SetOptions(merge: true));
  }

  Future<void> setEmergencyContacts(List<Map<String, String>> contacts) {
    return _myDoc.set({'emergencyContacts': contacts}, SetOptions(merge: true));
  }

  Future<void> setNotificationsPrefs(Map<String, bool> prefs) {
    return _myDoc
        .set({'notificationsPrefs': prefs}, SetOptions(merge: true));
  }

  Future<void> setPrivacyPrefs(Map<String, bool> prefs) {
    return _myDoc.set({'privacyPrefs': prefs}, SetOptions(merge: true));
  }

  /// 举报用户或帖子，写入 reports 集合。
  Future<void> report({
    required String targetId,
    required String targetType,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': _uid,
      'targetId': targetId,
      'targetType': targetType,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> blockUser(String targetUid) {
    return _myDoc.set({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser(String targetUid) {
    return _myDoc.set({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> watchBlockedProfiles(
      List<String> blockedUids) async* {
    if (blockedUids.isEmpty) {
      yield const [];
      return;
    }
    // Firestore whereIn 上限 30，这里简单取前 30 个。
    final ids = blockedUids.take(30).toList();
    final stream = _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: ids)
        .snapshots();
    await for (final snap in stream) {
      yield snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }
  }
}
