import 'package:dazi_app/data/models/circle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircleRole.fromString', () {
    test('已知角色正确解析', () {
      expect(CircleRole.fromString('owner'), CircleRole.owner);
      expect(CircleRole.fromString('admin'), CircleRole.admin);
      expect(CircleRole.fromString('member'), CircleRole.member);
    });

    test('null / 未知角色回退为 member', () {
      expect(CircleRole.fromString(null), CircleRole.member);
      expect(CircleRole.fromString('unknown'), CircleRole.member);
      expect(CircleRole.fromString(''), CircleRole.member);
    });
  });

  group('CircleRole.value', () {
    test('value 与 fromString 互逆', () {
      for (final role in CircleRole.values) {
        expect(CircleRole.fromString(role.value), role);
      }
    });
  });
}
