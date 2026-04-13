import 'package:dazi_app/data/models/post.dart';
import 'package:dazi_app/data/repositories/search_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post.fromAlgoliaHit', () {
    test('完整字段映射 —— ms 时间戳、_geoloc、枚举', () {
      final hit = <String, dynamic>{
        'objectID': 'post_123',
        'title': '周末爬山',
        'description': '香山路线',
        'category': '运动',
        'locationName': '香山公园南门',
        'city': '北京',
        '_geoloc': {'lat': 39.99, 'lng': 116.19},
        'time': 1700000000000,
        'costType': 'aa',
        'isSocialAnxietyFriendly': true,
        'isInstant': false,
        'status': 'open',
        'totalSlots': 6,
        'createdAt': 1699999000000,
      };

      final post = Post.fromAlgoliaHit(hit);

      expect(post.id, 'post_123');
      expect(post.title, '周末爬山');
      expect(post.description, '香山路线');
      expect(post.category, '运动');
      expect(post.totalSlots, 6);
      expect(post.isSocialAnxietyFriendly, true);
      expect(post.isInstant, false);
      expect(post.status, PostStatus.open);
      expect(post.costType, CostType.aa);
      expect(
        post.time,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(
        post.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1699999000000),
      );
      expect(post.location, isNotNull);
      expect(post.location!.name, '香山公园南门');
      expect(post.location!.city, '北京');
      expect(post.location!.lat, 39.99);
      expect(post.location!.lng, 116.19);
    });

    test('空字段 —— 给出安全默认值而不抛异常', () {
      final post = Post.fromAlgoliaHit(<String, dynamic>{});

      expect(post.id, '');
      expect(post.title, '');
      expect(post.description, '');
      expect(post.time, isNull);
      expect(post.createdAt, isNull);
      expect(post.location, isNull);
      expect(post.totalSlots, 0);
      expect(post.status, PostStatus.open);
      expect(post.costType, CostType.tbd);
      expect(post.images, isEmpty);
      expect(post.waitlist, isEmpty);
    });

    test('只有 locationName —— 构造 location 但 lat/lng 为 null', () {
      final post = Post.fromAlgoliaHit(<String, dynamic>{
        'objectID': 'x',
        'locationName': '星巴克',
      });
      expect(post.location, isNotNull);
      expect(post.location!.name, '星巴克');
      expect(post.location!.lat, isNull);
      expect(post.location!.lng, isNull);
      expect(post.location!.city, isNull);
    });

    test('只有 _geoloc —— 构造 location（name 空串）', () {
      final post = Post.fromAlgoliaHit(<String, dynamic>{
        'objectID': 'x',
        '_geoloc': {'lat': 31.2, 'lng': 121.4},
      });
      expect(post.location, isNotNull);
      expect(post.location!.lat, 31.2);
      expect(post.location!.lng, 121.4);
    });

    test('num 到 int/double 转换容错 —— 整数表示的坐标', () {
      final post = Post.fromAlgoliaHit(<String, dynamic>{
        'objectID': 'x',
        'totalSlots': 4.0,
        '_geoloc': {'lat': 40, 'lng': 116},
        'time': 1700000000000.0,
      });
      expect(post.totalSlots, 4);
      expect(post.location!.lat, 40.0);
      expect(post.location!.lng, 116.0);
      expect(post.time, isNotNull);
    });
  });

  group('SearchQuery', () {
    test('相同字段相等且 hashCode 一致', () {
      const a = SearchQuery(query: '火锅', city: '北京', category: '吃喝');
      const b = SearchQuery(query: '火锅', city: '北京', category: '吃喝');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('query 不同则不等', () {
      const a = SearchQuery(query: '火锅');
      const b = SearchQuery(query: '烧烤');
      expect(a, isNot(equals(b)));
    });

    test('city / category 不同则不等', () {
      const a = SearchQuery(query: '火锅', city: '北京');
      const b = SearchQuery(query: '火锅', city: '上海');
      expect(a, isNot(equals(b)));

      const c = SearchQuery(query: '火锅', category: '吃喝');
      const d = SearchQuery(query: '火锅', category: '文艺');
      expect(c, isNot(equals(d)));
    });
  });
}
