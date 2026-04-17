import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/safety_alert.dart';
import 'application_repository.dart' show firebaseFunctionsProvider;
import 'auth_repository.dart';

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  return SafetyRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

/// 安全伴侣仓库 —— 监听安全提醒 + 调用 confirmSafety。
class SafetyRepository {
  SafetyRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// 监听当前用户的 pending 安全提醒。
  Stream<List<SafetyAlert>> watchPendingAlerts(String uid) {
    return _firestore
        .collection('safetyAlerts')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.map(SafetyAlert.fromFirestore).toList());
  }

  /// 确认安全 —— 调用 Cloud Function。
  Future<void> confirmSafety() async {
    final callable = _functions.httpsCallable('confirmSafety');
    await callable.call<Map<dynamic, dynamic>>({});
  }
}

/// 当前用户的 pending 安全提醒列表。
final pendingSafetyAlertsProvider = StreamProvider<List<SafetyAlert>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(safetyRepositoryProvider).watchPendingAlerts(user.uid);
});
