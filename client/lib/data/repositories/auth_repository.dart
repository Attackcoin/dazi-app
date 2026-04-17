import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final firebaseStorageProvider =
    Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

/// 当前登录用户的 stream。null 表示未登录。
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// 当前登录用户的扩展资料（从 Firestore 读取）。
final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((snap) => snap.exists ? AppUser.fromFirestore(snap) : null);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

class AuthRepository {
  AuthRepository({required FirebaseAuth auth, required FirebaseFirestore firestore})
      : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? _verificationId;

  /// 发送手机验证码。[phone] 应为带国家码的完整号码（如 +8613800138000）。
  /// 当 codeSent 或 verificationCompleted 触发时 Future 完成。
  Future<void> sendPhoneCode(String phone) {
    final fullPhone = phone.startsWith('+') ? phone : '+$phone';
    final completer = Completer<void>();

    _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        // Android 自动识别验证码时直接登录
        await _auth.signInWithCredential(credential);
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  /// 提交用户输入的验证码完成登录。
  Future<UserCredential> verifyCode(String code) async {
    if (_verificationId == null) {
      throw StateError('请先发送验证码');
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );
    final result = await _auth.signInWithCredential(credential);
    if (result.user != null) {
      await _ensureUserDocument(result.user!);
    }
    return result;
  }

  /// 确保登录用户在 Firestore 中有对应的资料文档。
  ///
  /// 字段严格按 firestore.rules `users create` 白名单写入，
  /// 信誉/风控字段必须为默认值（rules 校验 == 0 / false）。
  Future<void> _ensureUserDocument(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': user.displayName ?? '搭子${user.uid.substring(0, 4)}',
        'avatar': user.photoURL ?? '',
        'bio': '',
        'gender': 'other',
        'city': '',
        'tags': <String>[],
        'sesameAuthorized': false,
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
    } else {
      await ref.update({'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  // ── Email/Password 认证 ──────────────────────────────

  /// 用邮箱+密码登录（已绑定邮箱的用户后续登录使用）。
  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (result.user != null) {
      await _ensureUserDocument(result.user!);
    }
    return result;
  }

  /// 将邮箱+密码绑定到当前已登录账号（手机注册后设置）。
  Future<void> linkEmailPassword(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('请先登录');
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.linkWithCredential(credential);
  }

  /// 当前用户是否已绑定邮箱+密码登录方式。
  bool get hasEmailProvider {
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  /// 当前用户已绑定的邮箱（如有）。
  String? get linkedEmail {
    final user = _auth.currentUser;
    if (user == null) return null;
    for (final p in user.providerData) {
      if (p.providerId == 'password') return p.email;
    }
    return null;
  }

  Future<void> signOut() => _auth.signOut();
}
