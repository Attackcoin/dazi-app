import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match.dart';
import 'auth_repository.dart';

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(firestore: ref.watch(firestoreProvider));
});

/// 读取 matches 集合（当前用户参与的搭子关系）。
class MatchRepository {
  MatchRepository({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<AppMatch>> watchMyMatches(String uid, {int limit = 50}) {
    return _firestore
        .collection('matches')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppMatch.fromFirestore).toList());
  }

  Stream<AppMatch?> watchMatch(String id) {
    return _firestore.collection('matches').doc(id).snapshots().map(
          (snap) => snap.exists ? AppMatch.fromFirestore(snap) : null,
        );
  }
}

/// 当前登录用户的搭子关系列表。
final myMatchesProvider = StreamProvider<List<AppMatch>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(matchRepositoryProvider).watchMyMatches(user.uid);
});

final matchByIdProvider = StreamProvider.family<AppMatch?, String>((ref, id) {
  return ref.watch(matchRepositoryProvider).watchMatch(id);
});
