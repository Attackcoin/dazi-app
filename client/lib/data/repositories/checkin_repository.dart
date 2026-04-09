import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application_repository.dart';

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(functions: ref.watch(firebaseFunctionsProvider));
});

/// 签到仓库 —— 调用 Cloud Function `submitCheckin`（asia-east1）。
class CheckinRepository {
  CheckinRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  /// 提交签到。`lat`/`lng` 可选——传入时后端会校验 500m 内。
  ///
  /// 返回 `true` 表示双方都已签到，活动已完成。
  Future<bool> submit({
    required String matchId,
    double? lat,
    double? lng,
  }) async {
    final callable = _functions.httpsCallable('submitCheckin');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    return resp.data['allCheckedIn'] as bool? ?? false;
  }
}
