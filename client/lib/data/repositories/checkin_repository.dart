import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application_repository.dart';

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(functions: ref.watch(firebaseFunctionsProvider));
});

/// 签到仓库 —— 调用 Cloud Function `submitCheckin`（asia-southeast1）。
class CheckinRepository {
  CheckinRepository({required FirebaseFunctions functions})
      : _functions = functions;

  final FirebaseFunctions _functions;

  /// 提交签到。`lat`/`lng` 可选——传入时后端会校验 500m 内。
  /// `scannedUid` 可选——扫码签到时传入，后端用于验证对方身份防作弊。
  ///
  /// 返回 `true` 表示双方都已签到，活动已完成。
  Future<bool> submit({
    required String matchId,
    double? lat,
    double? lng,
    String? scannedUid,
  }) async {
    final callable = _functions.httpsCallable('submitCheckin');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'matchId': matchId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (scannedUid != null) 'scannedUid': scannedUid,
    });
    return resp.data['allCheckedIn'] as bool? ?? false;
  }
}
