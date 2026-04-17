import 'package:cloud_firestore/cloud_firestore.dart';

/// 安全提醒 —— 对应 Firestore `safetyAlerts` 集合。
///
/// 当签到窗口超时且未签到时，后端自动创建安全提醒。
/// 用户可通过"平安签到"确认自己安全。
class SafetyAlert {
  final String id;
  final String matchId;
  final String uid;
  final SafetyAlertStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;

  const SafetyAlert({
    required this.id,
    required this.matchId,
    required this.uid,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.confirmedAt,
  });

  factory SafetyAlert.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return SafetyAlert(
      id: doc.id,
      matchId: data['matchId'] as String? ?? '',
      uid: data['uid'] as String? ?? '',
      status: SafetyAlertStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      confirmedAt: (data['confirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool get isPending => status == SafetyAlertStatus.pending;
}

enum SafetyAlertStatus {
  pending('pending'),
  confirmed('confirmed'),
  escalated('escalated');

  final String value;
  const SafetyAlertStatus(this.value);

  static SafetyAlertStatus fromString(String? v) =>
      SafetyAlertStatus.values.firstWhere(
        (e) => e.value == v,
        orElse: () => SafetyAlertStatus.pending,
      );
}
