import 'package:dazi_app/data/models/venue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Venue.fromMap', () {
    test('完整字段映射', () {
      final venue = Venue.fromMap({
        'id': 'v1',
        'name': '星巴克臻选烘焙工坊',
        'description': '全球最大星巴克',
        'category': 'cafe',
        'address': '上海市静安区南京西路789号',
        'lat': 31.2304,
        'lng': 121.4737,
        'coverImage': 'https://img.test/cover.jpg',
        'images': ['https://img.test/1.jpg', 'https://img.test/2.jpg'],
        'perks': ['免费咖啡', '9折优惠'],
        'isActive': true,
        'totalCheckins': 128,
      });

      expect(venue.id, 'v1');
      expect(venue.name, '星巴克臻选烘焙工坊');
      expect(venue.description, '全球最大星巴克');
      expect(venue.category, 'cafe');
      expect(venue.address, '上海市静安区南京西路789号');
      expect(venue.lat, 31.2304);
      expect(venue.lng, 121.4737);
      expect(venue.coverImage, 'https://img.test/cover.jpg');
      expect(venue.images, hasLength(2));
      expect(venue.perks, ['免费咖啡', '9折优惠']);
      expect(venue.isActive, true);
      expect(venue.totalCheckins, 128);
      expect(venue.createdAt, isNull);
    });

    test('空 Map —— 安全默认值', () {
      final venue = Venue.fromMap({});

      expect(venue.id, '');
      expect(venue.name, '');
      expect(venue.description, '');
      expect(venue.category, '');
      expect(venue.address, '');
      expect(venue.lat, 0);
      expect(venue.lng, 0);
      expect(venue.coverImage, '');
      expect(venue.images, isEmpty);
      expect(venue.perks, isEmpty);
      expect(venue.isActive, false);
      expect(venue.totalCheckins, 0);
    });

    test('num 类型兼容 —— int 表示的坐标', () {
      final venue = Venue.fromMap({
        'lat': 31,
        'lng': 121,
        'totalCheckins': 42.0,
      });

      expect(venue.lat, 31.0);
      expect(venue.lng, 121.0);
      expect(venue.totalCheckins, 42);
    });
  });
}
