import 'package:cloud_firestore/cloud_firestore.dart';

/// 搭子匹配关系 —— 对应 Firestore `matches` 集合。
///
/// 当申请被接受后由后端 Cloud Function 创建。
class AppMatch {
  final String id;
  final String postId;
  final String postTitle;
  final String postCategory;
  final DateTime? postTime;
  final String chatId;
  final List<String> participants;
  final Map<String, MatchParticipant> participantInfo;
  final MatchStatus status;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final List<String> checkedIn;
  final bool checkinWindowOpen;
  final DateTime? checkinWindowExpiresAt;

  const AppMatch({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.postCategory,
    required this.postTime,
    required this.chatId,
    required this.participants,
    required this.participantInfo,
    required this.status,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessagePreview,
    required this.checkedIn,
    required this.checkinWindowOpen,
    required this.checkinWindowExpiresAt,
  });

  bool hasCheckedIn(String uid) => checkedIn.contains(uid);
  bool get allCheckedIn =>
      participants.isNotEmpty && participants.every(checkedIn.contains);

  /// 在双人匹配中返回「对方」的信息。
  MatchParticipant? otherOf(String myUid) {
    final otherId = participants.firstWhere(
      (id) => id != myUid,
      orElse: () => '',
    );
    if (otherId.isEmpty) return null;
    return participantInfo[otherId];
  }

  factory AppMatch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final infoRaw = data['participantInfo'] as Map<String, dynamic>? ?? const {};
    final info = infoRaw.map(
      (k, v) => MapEntry(
        k,
        MatchParticipant.fromMap(v as Map<String, dynamic>),
      ),
    );
    return AppMatch(
      id: doc.id,
      postId: data['postId'] as String? ?? '',
      postTitle: data['postTitle'] as String? ?? '',
      postCategory: data['postCategory'] as String? ?? '',
      // 后端 acceptApplication 写入 `meetTime` 字段；兼容 `postTime` 作为回退。
      postTime: (data['meetTime'] as Timestamp?)?.toDate() ??
          (data['postTime'] as Timestamp?)?.toDate(),
      chatId: data['chatId'] as String? ?? doc.id,
      participants:
          (data['participants'] as List<dynamic>?)?.cast<String>() ?? const [],
      participantInfo: info,
      status: MatchStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessagePreview: data['lastMessagePreview'] as String?,
      checkedIn:
          (data['checkedIn'] as List<dynamic>?)?.cast<String>() ?? const [],
      checkinWindowOpen: data['checkinWindowOpen'] as bool? ?? false,
      checkinWindowExpiresAt:
          (data['checkinWindowExpiresAt'] as Timestamp?)?.toDate(),
    );
  }
}

class MatchParticipant {
  final String uid;
  final String name;
  final String avatar;

  const MatchParticipant({
    required this.uid,
    required this.name,
    required this.avatar,
  });

  factory MatchParticipant.fromMap(Map<String, dynamic> m) => MatchParticipant(
        uid: m['uid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        avatar: m['avatar'] as String? ?? '',
      );
}

enum MatchStatus {
  confirmed('confirmed'),
  completed('completed'),
  ghosted('ghosted'),
  ghostedAll('ghosted_all'),
  cancelled('cancelled');

  final String value;
  const MatchStatus(this.value);

  static MatchStatus fromString(String? v) => MatchStatus.values
      .firstWhere((e) => e.value == v, orElse: () => MatchStatus.confirmed);
}
