import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import 'auth_repository.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(firestore: ref.watch(firestoreProvider));
});

class PostRepository {
  PostRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// 广场首页：按城市过滤的可报名帖子（open 状态、未过期）。
  /// 按创建时间倒序，分页由调用方 limit 控制。
  Stream<List<Post>> watchFeed({
    String? city,
    String? category,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (city != null && city.isNotEmpty) {
      query = query.where('location.city', isEqualTo: city);
    }
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
          (snap) => snap.docs.map(Post.fromFirestore).toList(),
        );
  }

  Stream<Post?> watchPost(String id) {
    return _firestore.collection('posts').doc(id).snapshots().map(
          (snap) => snap.exists ? Post.fromFirestore(snap) : null,
        );
  }

  /// 某个用户发布的帖子列表（按创建时间倒序）。
  /// 用于 profile 页"我发布的"分区。限 [limit] 条防止大列表拖慢。
  Stream<List<Post>> watchPostsByUser(String uid, {int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromFirestore).toList());
  }
}

/// 广场 feed provider — 可按城市/分类过滤。
final feedProvider = StreamProvider.family<List<Post>, FeedQuery>((ref, q) {
  return ref.watch(postRepositoryProvider).watchFeed(
        city: q.city,
        category: q.category,
      );
});

final postByIdProvider = StreamProvider.family<Post?, String>((ref, id) {
  return ref.watch(postRepositoryProvider).watchPost(id);
});

/// 某 uid 发布的帖子列表。profile 页"我发布的"分区使用。
final postsByUserProvider = StreamProvider.family<List<Post>, String>((ref, uid) {
  return ref.watch(postRepositoryProvider).watchPostsByUser(uid);
});

class FeedQuery {
  final String? city;
  final String? category;

  const FeedQuery({this.city, this.category});

  @override
  bool operator ==(Object other) =>
      other is FeedQuery && other.city == city && other.category == category;

  @override
  int get hashCode => Object.hash(city, category);
}
