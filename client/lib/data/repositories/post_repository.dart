import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import 'application_repository.dart' show firebaseFunctionsProvider;
import 'auth_repository.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
  );
});

class PostRepository {
  PostRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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

  /// 加载更多帖子（游标分页）。一次性读取，非 Stream。
  Future<List<Post>> loadMoreFeed({
    String? city,
    String? category,
    required DocumentSnapshot lastDoc,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit);

    if (city != null && city.isNotEmpty) {
      query = query.where('location.city', isEqualTo: city);
    }
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }

    final snap = await query.get();
    return snap.docs.map(Post.fromFirestore).toList();
  }

  /// 获取文档快照（用于分页游标）。
  Future<DocumentSnapshot?> getPostSnapshot(String id) {
    return _firestore.collection('posts').doc(id).get();
  }

  Stream<Post?> watchPost(String id) {
    return _firestore.collection('posts').doc(id).snapshots().map(
          (snap) => snap.exists ? Post.fromFirestore(snap) : null,
        );
  }

  /// 系列帖子列表 —— 按 seriesId 查询并按 seriesWeek 排序。
  Stream<List<Post>> watchSeriesPosts(String seriesId) {
    return _firestore
        .collection('posts')
        .where('seriesId', isEqualTo: seriesId)
        .orderBy('seriesWeek')
        .snapshots()
        .map((snap) => snap.docs.map(Post.fromFirestore).toList());
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

  /// AI 个性化推荐帖子（调用 getRecommendedPosts Cloud Function）。
  Future<List<String>> getRecommendedPostIds({int limit = 20}) async {
    final callable = _functions.httpsCallable('getRecommendedPosts');
    final resp = await callable.call<Map<dynamic, dynamic>>({'limit': limit});
    final posts = resp.data['posts'] as List<dynamic>? ?? [];
    return posts.map((p) => (p as Map)['id'] as String).toList();
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

/// 系列活动中所有帖子（按 seriesWeek 升序排列）。
final seriesPostsProvider = StreamProvider.family<List<Post>, String>((ref, seriesId) {
  return ref.watch(postRepositoryProvider).watchSeriesPosts(seriesId);
});

/// AI 推荐帖子 ID 列表（一次性加载）。
final recommendedPostIdsProvider = FutureProvider<List<String>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Future.value(const []);
  return ref.watch(postRepositoryProvider).getRecommendedPostIds();
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
