import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/region_config.dart';
import '../models/circle.dart';
import 'auth_repository.dart';

final circleRepositoryProvider = Provider<CircleRepository>((ref) {
  final region = RegionConfig.resolveFunctionsRegion();
  return CircleRepository(
    firestore: ref.watch(firestoreProvider),
    functions: FirebaseFunctions.instanceFor(region: region),
  );
});

class CircleRepository {
  CircleRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// 获取圈子列表（按成员数降序）。
  Stream<List<Circle>> watchCircles({int limit = 30}) {
    return _firestore
        .collection('circles')
        .orderBy('memberCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Circle.fromFirestore(d)).toList());
  }

  /// 获取单个圈子。
  Stream<Circle?> watchCircle(String circleId) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .snapshots()
        .map((snap) => snap.exists ? Circle.fromFirestore(snap) : null);
  }

  /// 获取圈子的成员列表。
  Stream<List<CircleMember>> watchMembers(String circleId, {int limit = 50}) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('members')
        .orderBy('joinedAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CircleMember.fromFirestore(d)).toList());
  }

  /// 查看当前用户是否为圈子成员。
  Stream<CircleMember?> watchMyMembership(String circleId, String uid) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? CircleMember.fromFirestore(snap) : null);
  }

  /// 获取圈子动态。
  Stream<List<CircleMoment>> watchMoments(String circleId, {int limit = 30}) {
    return _firestore
        .collection('circles')
        .doc(circleId)
        .collection('moments')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CircleMoment.fromFirestore(d)).toList());
  }

  /// 创建圈子。
  Future<String> createCircle({
    required String name,
    String description = '',
    String category = '',
    String icon = '',
  }) async {
    final callable = _functions.httpsCallable('createCircle');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'name': name,
      'description': description,
      'category': category,
      'icon': icon,
    });
    return resp.data['circleId'] as String;
  }

  /// 加入圈子。
  Future<void> joinCircle(String circleId) async {
    final callable = _functions.httpsCallable('joinCircle');
    await callable.call<Map<dynamic, dynamic>>({'circleId': circleId});
  }

  /// 退出圈子。
  Future<void> leaveCircle(String circleId) async {
    final callable = _functions.httpsCallable('leaveCircle');
    await callable.call<Map<dynamic, dynamic>>({'circleId': circleId});
  }

  /// 发动态。
  Future<String> postMoment({
    required String circleId,
    required String text,
    List<String> images = const [],
  }) async {
    final callable = _functions.httpsCallable('postMoment');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'circleId': circleId,
      'text': text,
      'images': images,
    });
    return resp.data['momentId'] as String;
  }
}

// ─── Riverpod providers ─────────────────────────────

/// 圈子列表流。
final circlesProvider = StreamProvider<List<Circle>>((ref) {
  return ref.watch(circleRepositoryProvider).watchCircles();
});

/// 单个圈子详情流。
final circleProvider =
    StreamProvider.family<Circle?, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).watchCircle(circleId);
});

/// 当前用户在某圈子的成员身份。
final myCircleMembershipProvider =
    StreamProvider.family<CircleMember?, String>((ref, circleId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(circleRepositoryProvider)
      .watchMyMembership(circleId, uid);
});

/// 圈子成员列表流。
final circleMembersProvider =
    StreamProvider.family<List<CircleMember>, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).watchMembers(circleId);
});

/// 圈子动态流。
final circleMomentsProvider =
    StreamProvider.family<List<CircleMoment>, String>((ref, circleId) {
  return ref.watch(circleRepositoryProvider).watchMoments(circleId);
});
