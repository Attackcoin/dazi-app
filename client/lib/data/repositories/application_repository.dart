import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/application.dart';
import 'auth_repository.dart';

/// Cloud Functions 部署区域 —— 与 functions/src/applications.js 保持一致。
const _functionsRegion = 'asia-east1';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instanceFor(region: _functionsRegion);
});

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return ApplicationRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

class ApplicationRepository {
  ApplicationRepository({
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
  })  : _functions = functions,
        _firestore = firestore;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  /// 申请加入某个搭子。返回后端分配的 applicationId + 状态（pending / waitlisted）。
  Future<ApplyResult> applyToPost(String postId) async {
    final callable = _functions.httpsCallable('applyToPost');
    final resp = await callable.call<Map<dynamic, dynamic>>({'postId': postId});
    final data = resp.data;
    return ApplyResult(
      applicationId: data['applicationId'] as String? ?? '',
      status: ApplicationStatus.fromString(data['status'] as String?),
    );
  }

  /// 发布者接受一条申请。
  Future<String?> acceptApplication(String applicationId) async {
    final callable = _functions.httpsCallable('acceptApplication');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'applicationId': applicationId,
    });
    return resp.data['matchId'] as String?;
  }

  /// 发布者拒绝一条申请。
  Future<void> rejectApplication(String applicationId, {String? reason}) async {
    final callable = _functions.httpsCallable('rejectApplication');
    await callable.call<Map<dynamic, dynamic>>({
      'applicationId': applicationId,
      if (reason != null) 'reason': reason,
    });
  }

  /// 监听当前登录用户对某个 post 的现有申请（若存在）。
  Stream<Application?> watchMyApplication({
    required String postId,
    required String uid,
  }) {
    return _firestore
        .collection('applications')
        .where('postId', isEqualTo: postId)
        .where('applicantId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) =>
            snap.docs.isEmpty ? null : Application.fromFirestore(snap.docs.first));
  }

  /// 发布者查看某个 post 的全部申请。
  Stream<List<Application>> watchApplicationsForPost(String postId) {
    return _firestore
        .collection('applications')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Application.fromFirestore).toList());
  }
}

class ApplyResult {
  final String applicationId;
  final ApplicationStatus status;

  const ApplyResult({required this.applicationId, required this.status});
}

/// 查询当前用户对某个 post 的申请状态（只读），用于切换按钮展示。
final myApplicationForPostProvider =
    StreamProvider.family<Application?, String>((ref, postId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(applicationRepositoryProvider)
      .watchMyApplication(postId: postId, uid: uid);
});

/// 发布者视角：某个 post 的全部申请流。
final applicationsForPostProvider =
    StreamProvider.family<List<Application>, String>((ref, postId) {
  return ref
      .watch(applicationRepositoryProvider)
      .watchApplicationsForPost(postId);
});
