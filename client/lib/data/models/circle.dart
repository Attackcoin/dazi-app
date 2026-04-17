import 'package:cloud_firestore/cloud_firestore.dart';

/// 兴趣圈子 —— 对应 Firestore `circles` 集合。
class Circle {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final String coverImage;
  final int memberCount;
  final int postCount;
  final String createdBy;
  final String creatorName;
  final DateTime? createdAt;

  const Circle({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.coverImage,
    required this.memberCount,
    required this.postCount,
    required this.createdBy,
    required this.creatorName,
    this.createdAt,
  });

  factory Circle.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Circle(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      icon: data['icon'] as String? ?? '',
      coverImage: data['coverImage'] as String? ?? '',
      memberCount: data['memberCount'] as int? ?? 0,
      postCount: data['postCount'] as int? ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      creatorName: data['creatorName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 圈子成员 —— 对应 `circles/{id}/members/{uid}` 子集合。
class CircleMember {
  final String uid;
  final String name;
  final String avatar;
  final CircleRole role;
  final DateTime? joinedAt;

  const CircleMember({
    required this.uid,
    required this.name,
    required this.avatar,
    required this.role,
    this.joinedAt,
  });

  factory CircleMember.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CircleMember(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      avatar: data['avatar'] as String? ?? '',
      role: CircleRole.fromString(data['role'] as String?),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}

enum CircleRole {
  owner('owner'),
  admin('admin'),
  member('member');

  final String value;
  const CircleRole(this.value);

  static CircleRole fromString(String? v) => CircleRole.values.firstWhere(
        (e) => e.value == v,
        orElse: () => CircleRole.member,
      );
}

/// 圈子动态 —— 对应 `circles/{id}/moments/{momentId}` 子集合。
class CircleMoment {
  final String id;
  final String uid;
  final String authorName;
  final String authorAvatar;
  final String text;
  final List<String> images;
  final int likeCount;
  final DateTime? createdAt;

  const CircleMoment({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.images,
    required this.likeCount,
    this.createdAt,
  });

  factory CircleMoment.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CircleMoment(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorAvatar: data['authorAvatar'] as String? ?? '',
      text: data['text'] as String? ?? '',
      images: List<String>.from(data['images'] as List? ?? []),
      likeCount: data['likeCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
