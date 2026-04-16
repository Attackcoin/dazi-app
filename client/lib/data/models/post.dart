import 'package:cloud_firestore/cloud_firestore.dart';

/// 搭子活动帖子模型
///
/// 对应 Firestore `posts` 集合文档。
class Post {
  final String id;
  final String userId;
  final String category;
  final String title;
  final String description;
  final List<String> images;
  final DateTime? time;
  final PostLocation? location;
  final int totalSlots;
  final int minSlots;
  final GenderQuota? genderQuota;
  final GenderCount acceptedGender;
  final CostType costType;
  final int depositAmount;
  final bool isInstant;
  final bool isSocialAnxietyFriendly;
  final List<String> waitlist;
  final PostStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? shareUrl;
  final String? publisherName;
  final String? publisherAvatar;

  const Post({
    required this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.description,
    required this.images,
    required this.time,
    required this.location,
    required this.totalSlots,
    required this.minSlots,
    required this.genderQuota,
    required this.acceptedGender,
    required this.costType,
    required this.depositAmount,
    required this.isInstant,
    required this.isSocialAnxietyFriendly,
    required this.waitlist,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.shareUrl,
    this.publisherName,
    this.publisherAvatar,
  });

  int get acceptedCount => acceptedGender.male + acceptedGender.female;
  double get slotProgress =>
      totalSlots == 0 ? 0 : (acceptedCount / totalSlots).clamp(0, 1);
  bool get isFull => acceptedCount >= totalSlots;

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Post(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      category: data['category'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      images: (data['images'] as List<dynamic>?)?.cast<String>() ?? const [],
      time: (data['time'] as Timestamp?)?.toDate(),
      location: data['location'] is Map<String, dynamic>
          ? PostLocation.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      totalSlots: (data['totalSlots'] as num?)?.toInt() ?? 0,
      minSlots: (data['minSlots'] as num?)?.toInt() ?? 2,
      genderQuota: data['genderQuota'] is Map<String, dynamic>
          ? GenderQuota.fromMap(data['genderQuota'] as Map<String, dynamic>)
          : null,
      acceptedGender: data['acceptedGender'] is Map<String, dynamic>
          ? GenderCount.fromMap(
              data['acceptedGender'] as Map<String, dynamic>,
            )
          : const GenderCount(male: 0, female: 0),
      costType: CostType.fromString(data['costType'] as String?),
      depositAmount: (data['depositAmount'] as num?)?.toInt() ?? 0,
      isInstant: data['isInstant'] as bool? ?? false,
      isSocialAnxietyFriendly: data['isSocialAnxietyFriendly'] as bool? ?? false,
      waitlist: (data['waitlist'] as List<dynamic>?)?.cast<String>() ?? const [],
      status: PostStatus.fromString(data['status'] as String?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      shareUrl: data['shareUrl'] as String?,
      publisherName: data['publisherName'] as String?,
      publisherAvatar: data['publisherAvatar'] as String?,
    );
  }

  /// 从 Algolia hit 构造 Post（仅包含搜索所需字段；非搜索字段给安全默认值）。
  ///
  /// 与 `fromFirestore` 的关键差异：
  /// - `time` / `createdAt` 在 Algolia 里是 `int` 毫秒时间戳（见
  ///   `functions/src/algoliaSync.js:51,57`），而 Firestore 里是 `Timestamp`。
  /// - `location` 由 `locationName` + `city` + `_geoloc` 三个字段重建。
  /// - `objectID` 映射为 `id`。
  /// - 未同步到 Algolia 的字段（min/gender/waitlist/expires/shareUrl 等）
  ///   使用与 `fromFirestore` 空值路径一致的默认值。
  factory Post.fromAlgoliaHit(Map<String, dynamic> hit) {
    final timeMs = (hit['time'] as num?)?.toInt();
    final createdAtMs = (hit['createdAt'] as num?)?.toInt();

    PostLocation? location;
    final name = hit['locationName'] as String? ?? '';
    final city = hit['city'] as String? ?? '';
    final geo = hit['_geoloc'];
    double? lat;
    double? lng;
    if (geo is Map) {
      lat = (geo['lat'] as num?)?.toDouble();
      lng = (geo['lng'] as num?)?.toDouble();
    }
    if (name.isNotEmpty || city.isNotEmpty || lat != null || lng != null) {
      location = PostLocation(
        name: name,
        lat: lat,
        lng: lng,
        city: city.isEmpty ? null : city,
      );
    }

    return Post(
      id: (hit['objectID'] as String?) ?? '',
      userId: '',
      category: hit['category'] as String? ?? '',
      title: hit['title'] as String? ?? '',
      description: hit['description'] as String? ?? '',
      images: const [],
      time: timeMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timeMs),
      location: location,
      totalSlots: (hit['totalSlots'] as num?)?.toInt() ?? 0,
      minSlots: 2,
      genderQuota: null,
      acceptedGender: const GenderCount(male: 0, female: 0),
      costType: CostType.fromString(hit['costType'] as String?),
      depositAmount: 0,
      isInstant: hit['isInstant'] as bool? ?? false,
      isSocialAnxietyFriendly: hit['isSocialAnxietyFriendly'] as bool? ?? false,
      waitlist: const [],
      status: PostStatus.fromString(hit['status'] as String?),
      createdAt: createdAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      expiresAt: null,
      shareUrl: null,
      publisherName: hit['publisherName'] as String?,
      publisherAvatar: null, // Algolia 不同步头像 URL
    );
  }
}

class PostLocation {
  final String name;
  final double? lat;
  final double? lng;
  final String? city;

  const PostLocation({required this.name, this.lat, this.lng, this.city});

  factory PostLocation.fromMap(Map<String, dynamic> m) => PostLocation(
        name: m['name'] as String? ?? '',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        city: m['city'] as String?,
      );
}

class GenderQuota {
  final int? male;
  final int? female;

  const GenderQuota({this.male, this.female});

  factory GenderQuota.fromMap(Map<String, dynamic> m) => GenderQuota(
        male: (m['male'] as num?)?.toInt(),
        female: (m['female'] as num?)?.toInt(),
      );
}

class GenderCount {
  final int male;
  final int female;

  const GenderCount({required this.male, required this.female});

  factory GenderCount.fromMap(Map<String, dynamic> m) => GenderCount(
        male: (m['male'] as num?)?.toInt() ?? 0,
        female: (m['female'] as num?)?.toInt() ?? 0,
      );
}

enum CostType {
  aa('aa', 'AA 制'),
  host('host', '发起人请客'),
  self('self', '各付各的'),
  tbd('tbd', '见面协商');

  final String value;
  final String label;
  const CostType(this.value, this.label);

  static CostType fromString(String? v) =>
      CostType.values.firstWhere((e) => e.value == v, orElse: () => CostType.tbd);
}

enum PostStatus {
  open('open'),
  full('full'),
  done('done'),
  cancelled('cancelled'),
  expired('expired');

  final String value;
  const PostStatus(this.value);

  static PostStatus fromString(String? v) => PostStatus.values
      .firstWhere((e) => e.value == v, orElse: () => PostStatus.open);
}
