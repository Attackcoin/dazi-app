/// 一个活动分类（如"吃喝"），包含 emoji 和二级兴趣标签。
class CategoryConfig {
  const CategoryConfig({
    required this.id,
    required this.label,
    required this.emoji,
    required this.tags,
    this.sort = 0,
  });

  /// Firestore 字段名/查询值（如 "吃喝"）
  final String id;

  /// 展示名（通常与 id 相同）
  final String label;

  /// 分类图标 emoji
  final String emoji;

  /// 二级兴趣标签列表
  final List<String> tags;

  /// 排序权重，值越小越靠前
  final int sort;

  factory CategoryConfig.fromMap(Map<String, dynamic> map) {
    return CategoryConfig(
      id: (map['id'] as String?) ?? '',
      label: (map['label'] as String?) ?? (map['id'] as String?) ?? '',
      emoji: (map['emoji'] as String?) ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      sort: (map['sort'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'emoji': emoji,
        'tags': tags,
        'sort': sort,
      };
}
