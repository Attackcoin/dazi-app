import 'package:cloud_firestore/cloud_firestore.dart';

/// 申请记录模型 —— 对应 Firestore `applications` 集合。
///
/// 文档由 Cloud Function `applyToPost` 创建。
class Application {
  final String id;
  final String postId;
  final String applicantId;
  final ApplicationStatus status;
  final String? rejectReason;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  const Application({
    required this.id,
    required this.postId,
    required this.applicantId,
    required this.status,
    required this.rejectReason,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Application.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return Application(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      applicantId: data['applicantId'] as String? ?? '',
      status: ApplicationStatus.fromString(data['status'] as String?),
      rejectReason: data['rejectReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

enum ApplicationStatus {
  pending('pending', '审核中'),
  accepted('accepted', '已通过'),
  rejected('rejected', '已拒绝'),
  waitlisted('waitlisted', '候补中'),
  expired('expired', '已过期'),
  cancelled('cancelled', '已取消');

  final String value;
  final String label;
  const ApplicationStatus(this.value, this.label);

  bool get isActive => this == pending || this == waitlisted || this == accepted;

  static ApplicationStatus fromString(String? v) => ApplicationStatus.values
      .firstWhere((e) => e.value == v, orElse: () => ApplicationStatus.pending);
}
