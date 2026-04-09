import 'package:cloud_firestore/cloud_firestore.dart';

/// 搭子 App 用户模型 — 对应 Firestore `users` 集合。
class AppUser {
  final String id;
  final String name;
  final String avatar;
  final String bio;
  final String gender;
  final int? birthYear;
  final String phone;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final int ghostCount;
  final bool isRestricted;
  final int verificationLevel;
  final bool sesameAuthorized;
  final int totalMeetups;
  final List<String> badges;
  final String city;
  final List<String> blockedUsers;
  final List<Map<String, String>> emergencyContacts;
  final Map<String, bool> notificationsPrefs;
  final Map<String, bool> privacyPrefs;
  final DateTime? createdAt;
  final DateTime? lastActive;

  const AppUser({
    required this.id,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.gender,
    required this.birthYear,
    required this.phone,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.ghostCount,
    required this.isRestricted,
    required this.verificationLevel,
    required this.sesameAuthorized,
    required this.totalMeetups,
    required this.badges,
    required this.city,
    required this.blockedUsers,
    this.emergencyContacts = const [],
    this.notificationsPrefs = const {},
    this.privacyPrefs = const {},
    required this.createdAt,
    required this.lastActive,
  });

  int? get age {
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear!;
  }

  bool get isAdult => (age ?? 0) >= 18;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      name: data['name'] as String? ?? '',
      avatar: data['avatar'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      gender: data['gender'] as String? ?? 'other',
      birthYear: (data['birthYear'] as num?)?.toInt(),
      phone: data['phone'] as String? ?? '',
      tags: (data['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      ghostCount: (data['ghostCount'] as num?)?.toInt() ?? 0,
      isRestricted: data['isRestricted'] as bool? ?? false,
      verificationLevel: (data['verificationLevel'] as num?)?.toInt() ?? 1,
      sesameAuthorized: data['sesameAuthorized'] as bool? ?? false,
      totalMeetups: (data['totalMeetups'] as num?)?.toInt() ?? 0,
      badges: (data['badges'] as List<dynamic>?)?.cast<String>() ?? const [],
      city: data['city'] as String? ?? '',
      blockedUsers:
          (data['blockedUsers'] as List<dynamic>?)?.cast<String>() ?? const [],
      emergencyContacts: ((data['emergencyContacts'] as List<dynamic>?) ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
          .toList(),
      notificationsPrefs:
          ((data['notificationsPrefs'] as Map<dynamic, dynamic>?) ?? const {})
              .map((k, v) => MapEntry(k.toString(), v == true)),
      privacyPrefs: ((data['privacyPrefs'] as Map<dynamic, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v == true)),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreateMap() => {
        'name': name,
        'avatar': avatar,
        'bio': bio,
        'gender': gender,
        'birthYear': birthYear,
        'phone': phone,
        'tags': tags,
        'rating': 5.0,
        'reviewCount': 0,
        'ghostCount': 0,
        'isRestricted': false,
        'verificationLevel': 1,
        'sesameAuthorized': false,
        'totalMeetups': 0,
        'badges': <String>[],
        'city': city,
        'blockedUsers': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };
}
