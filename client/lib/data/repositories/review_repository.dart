import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(functions: ref.watch(firebaseFunctionsProvider));
});

/// 评价仓库 —— 调用 `submitReview` + `generateRecapCard`（asia-southeast1）。
class ReviewRepository {
  ReviewRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  /// 提交对对方的评价。
  Future<void> submit({
    required String matchId,
    required String toUserId,
    required int rating,
    String? comment,
    List<String> tags = const [],
  }) async {
    final callable = _functions.httpsCallable('submitReview');
    await callable.call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      'toUserId': toUserId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (tags.isNotEmpty) 'tags': tags,
    });
  }

  /// 手动触发回忆卡生成（正常情况下由后端在双方签到后自动生成）。
  Future<String?> generateRecap(String matchId) async {
    final callable = _functions.httpsCallable('generateRecapCard');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'matchId': matchId,
    });
    return resp.data['summary'] as String?;
  }
}
