import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
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
