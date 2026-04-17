import 'package:dazi_app/data/models/voice_room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceRoom.fromMap', () {
    test('完整字段映射', () {
      final room = VoiceRoom.fromMap({
        'id': 'r1',
        'title': '周末电影闲聊',
        'topic': '聊聊最近好看的电影',
        'category': '影视',
        'hostId': 'u1',
        'hostName': '张三',
        'hostAvatar': 'https://img.test/a.jpg',
        'maxParticipants': 10,
        'participants': ['u1', 'u2', 'u3'],
        'speakerIds': ['u1', 'u2'],
        'participantCount': 3,
        'isLive': true,
      });

      expect(room.id, 'r1');
      expect(room.title, '周末电影闲聊');
      expect(room.topic, '聊聊最近好看的电影');
      expect(room.category, '影视');
      expect(room.hostId, 'u1');
      expect(room.hostName, '张三');
      expect(room.hostAvatar, 'https://img.test/a.jpg');
      expect(room.maxParticipants, 10);
      expect(room.participants, ['u1', 'u2', 'u3']);
      expect(room.speakerIds, ['u1', 'u2']);
      expect(room.participantCount, 3);
      expect(room.isLive, true);
      expect(room.createdAt, isNull);
    });

    test('空 Map —— 安全默认值', () {
      final room = VoiceRoom.fromMap({});

      expect(room.id, '');
      expect(room.title, '');
      expect(room.topic, '');
      expect(room.category, '');
      expect(room.hostId, '');
      expect(room.hostName, '');
      expect(room.hostAvatar, '');
      expect(room.maxParticipants, 8);
      expect(room.participants, isEmpty);
      expect(room.speakerIds, isEmpty);
      expect(room.participantCount, 0);
      expect(room.isLive, false);
    });

    test('num 类型兼容 —— int/double 均可', () {
      final room = VoiceRoom.fromMap({
        'maxParticipants': 12.0,
        'participantCount': 5.0,
      });

      expect(room.maxParticipants, 12);
      expect(room.participantCount, 5);
    });
  });

  group('VoiceRoom 业务逻辑', () {
    VoiceRoom _makeRoom({
      String hostId = 'host1',
      List<String> participants = const ['host1', 'u2'],
      List<String> speakerIds = const ['host1'],
      int maxParticipants = 8,
      bool isLive = true,
    }) =>
        VoiceRoom(
          id: 'r1',
          title: 'Test Room',
          topic: '',
          category: '',
          hostId: hostId,
          hostName: 'Host',
          hostAvatar: '',
          maxParticipants: maxParticipants,
          participants: participants,
          speakerIds: speakerIds,
          participantCount: participants.length,
          isLive: isLive,
        );

    test('主持人在 participants 和 speakerIds 中', () {
      final room = _makeRoom();
      expect(room.participants.contains(room.hostId), true);
      expect(room.speakerIds.contains(room.hostId), true);
    });

    test('参与者人数和列表长度一致', () {
      final room = _makeRoom(participants: ['h', 'a', 'b', 'c']);
      expect(room.participantCount, room.participants.length);
    });

    test('isLive false 表示房间已结束', () {
      final room = _makeRoom(isLive: false);
      expect(room.isLive, false);
    });
  });
}
