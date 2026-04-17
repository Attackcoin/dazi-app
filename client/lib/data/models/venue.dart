import 'package:cloud_firestore/cloud_firestore.dart';

/// 合作场地 —— 对应 Firestore `venues` 集合。
class Venue {
  final String id;
  final String name;
  final String description;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final String coverImage;
  final List<String> images;
  final List<String> perks;
  final bool isActive;
  final int totalCheckins;
  final DateTime? createdAt;

  const Venue({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    required this.coverImage,
    required this.images,
    required this.perks,
    required this.isActive,
    required this.totalCheckins,
    this.createdAt,
  });

  factory Venue.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Venue(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      address: data['address'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      coverImage: data['coverImage'] as String? ?? '',
      images: List<String>.from(data['images'] as List? ?? []),
      perks: List<String>.from(data['perks'] as List? ?? []),
      isActive: data['isActive'] as bool? ?? false,
      totalCheckins: (data['totalCheckins'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 从 Cloud Function 返回的 Map 构造（listNearbyVenues 返回格式）。
  factory Venue.fromMap(Map<String, dynamic> data) {
    return Venue(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      address: data['address'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      coverImage: data['coverImage'] as String? ?? '',
      images: List<String>.from(data['images'] as List? ?? []),
      perks: List<String>.from(data['perks'] as List? ?? []),
      isActive: data['isActive'] as bool? ?? false,
      totalCheckins: (data['totalCheckins'] as num?)?.toInt() ?? 0,
      createdAt: null,
    );
  }
}
