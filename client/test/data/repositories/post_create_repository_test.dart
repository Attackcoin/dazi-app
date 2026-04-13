import 'package:dazi_app/data/repositories/post_create_repository.dart';
import 'package:dazi_app/data/models/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostDraft.validate', () {
    PostDraft makeFull() => PostDraft(
          category: '吃喝',
          title: '周末喝咖啡',
          description: '',
          time: DateTime.now().add(const Duration(days: 1)),
          locationName: '星巴克',
          city: '上海',
          totalSlots: 4,
          costType: CostType.aa,
        );

    test('完整草稿通过校验', () {
      expect(makeFull().validate(), isNull);
    });

    test('缺分类', () {
      final d = makeFull()..category = '';
      expect(d.validate(), '请选择分类');
    });

    test('标题为空或全空格', () {
      final d = makeFull()..title = '   ';
      expect(d.validate(), '请填写标题');
    });

    test('时间为 null', () {
      final d = makeFull()..time = null;
      expect(d.validate(), '请选择时间');
    });

    test('时间是过去的时间', () {
      final d = makeFull()..time = DateTime.now().subtract(const Duration(hours: 1));
      expect(d.validate(), '活动时间必须在未来');
    });

    test('地点为空', () {
      final d = makeFull()..locationName = '  ';
      expect(d.validate(), '请填写地点');
    });

    test('人数少于 2 人', () {
      final d = makeFull()..totalSlots = 1;
      expect(d.validate(), '人数不能少于 2 人');
    });

    test('男女配额之和超过总人数', () {
      final d = makeFull()
        ..totalSlots = 4
        ..maleQuota = 3
        ..femaleQuota = 3;
      expect(d.validate(), '男女配额之和不能超过总人数');
    });

    test('男女配额合理', () {
      final d = makeFull()
        ..totalSlots = 4
        ..maleQuota = 2
        ..femaleQuota = 2;
      expect(d.validate(), isNull);
    });
  });
}
