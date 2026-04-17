import 'package:cloud_firestore/cloud_firestore.dart';

/// 语音房 —— 对应 Firestore `voiceRooms` 集合。
class VoiceRoom {
  final String id;
  final String title;
  final String topic;
  final String category;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  final int maxParticipants;
  final List<String> participants;
  final List<String> speakerIds;
  final int participantCount;
  final bool isLive;
  final DateTime? createdAt;

  const VoiceRoom({
    required this.id,
    required this.title,
    required this.topic,
    required this.category,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
    required this.maxParticipants,
    required this.participants,
    required this.speakerIds,
    required this.participantCount,
    required this.isLive,
    this.createdAt,
  });

  factory VoiceRoom.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return VoiceRoom(
      id: doc.id,
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String? ?? '',
      category: data['category'] as String? ?? '',
      hostId: data['hostId'] as String? ?? '',
      hostName: data['hostName'] as String? ?? '',
      hostAvatar: data['hostAvatar'] as String? ?? '',
      maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 8,
      participants: List<String>.from(data['participants'] as List? ?? []),
      speakerIds: List<String>.from(data['speakerIds'] as List? ?? []),
      participantCount: (data['participantCount'] as num?)?.toInt() ?? 0,
      isLive: data['isLive'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 从 Cloud Function 返回的 Map 构造。
  factory VoiceRoom.fromMap(Map<String, dynamic> data) {
    return VoiceRoom(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      topic: data['topic'] as String? ?? '',
      category: data['category'] as String? ?? '',
      hostId: data['hostId'] as String? ?? '',
      hostName: data['hostName'] as String? ?? '',
      hostAvatar: data['hostAvatar'] as String? ?? '',
      maxParticipants: (data['maxParticipants'] as num?)?.toInt() ?? 8,
      participants: List<String>.from(data['participants'] as List? ?? []),
      speakerIds: List<String>.from(data['speakerIds'] as List? ?? []),
      participantCount: (data['participantCount'] as num?)?.toInt() ?? 0,
      isLive: data['isLive'] as bool? ?? false,
      createdAt: null,
    );
  }
}
