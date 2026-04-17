import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_config.dart';
import 'auth_repository.dart';

/// 从 Firestore `config/categories` 文档读取分类配置。
///
/// 文档结构：
/// ```json
/// {
///   "list": [
///     { "id": "吃喝", "label": "吃喝", "emoji": "🍜", "tags": ["咖啡","火锅",...], "sort": 0 },
///     ...
///   ]
/// }
/// ```
///
/// 如果文档不存在或读取失败，返回内置默认值。
final categoriesProvider = StreamProvider<List<CategoryConfig>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('config')
      .doc('categories')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return _defaults;
    final data = snap.data();
    if (data == null || data['list'] is! List) return _defaults;
    final list = (data['list'] as List)
        .map((e) => CategoryConfig.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return list.isEmpty ? _defaults : list;
  }).handleError((Object _) => _defaults);
});

/// 内置默认分类 —— 当 Firestore 文档不存在时使用。
/// 一旦在 Firebase Console 创建了 config/categories 文档，这里就不再生效。
const _defaults = [
  CategoryConfig(
    id: '吃喝', label: '吃喝', emoji: '🍜', sort: 0,
    tags: ['咖啡', '火锅', '日料', '烧烤', '甜品', '酒吧'],
  ),
  CategoryConfig(
    id: '运动', label: '运动', emoji: '🏃', sort: 1,
    tags: ['跑步', '健身', '瑜伽', '骑行', '羽毛球', '游泳', '爬山'],
  ),
  CategoryConfig(
    id: '文艺', label: '文艺', emoji: '🎨', sort: 2,
    tags: ['看展', '音乐节', 'Livehouse', '剧本杀', '话剧', '电影'],
  ),
  CategoryConfig(
    id: '旅行', label: '旅行', emoji: '✈️', sort: 3,
    tags: ['city walk', '露营', '自驾', '民宿', '打卡', '短途'],
  ),
  CategoryConfig(
    id: '学习', label: '学习', emoji: '📚', sort: 4,
    tags: ['自习', '英语', '读书会', '编程', '考研'],
  ),
  CategoryConfig(
    id: '演出', label: '演出', emoji: '🎤', sort: 5,
    tags: ['演唱会', '音乐节', '展览', '体育赛事'],
  ),
  CategoryConfig(
    id: '游戏', label: '游戏', emoji: '🎮', sort: 6,
    tags: ['桌游', '密室', '剧本杀', '电竞', '狼人杀'],
  ),
];
