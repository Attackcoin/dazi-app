import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/voice_room.dart';
import 'package:dazi_app/data/repositories/auth_repository.dart';
import 'package:dazi_app/data/repositories/voice_room_repository.dart';
import 'package:dazi_app/presentation/features/voice/voice_room_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: GlassTheme(
      data: GlassThemeData.dark,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: child,
      ),
    ),
  );
}

VoiceRoom _fakeRoom({
  String hostId = 'host1',
  List<String> participants = const ['host1', 'u2', 'u3'],
  List<String> speakerIds = const ['host1'],
  bool isLive = true,
  String topic = '聊聊最近好看的电影',
  String category = '影视',
}) =>
    VoiceRoom(
      id: 'r1',
      title: '周末电影闲聊',
      topic: topic,
      category: category,
      hostId: hostId,
      hostName: '张三',
      hostAvatar: '',
      maxParticipants: 8,
      participants: participants,
      speakerIds: speakerIds,
      participantCount: participants.length,
      isLive: isLive,
    );

/// 简单的 fake User，只需 uid。
class _FakeUser extends Fake implements User {
  _FakeUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

void main() {
  testWidgets('VoiceRoomDetailScreen —— loading 态', (tester) async {
    final controller = StreamController<VoiceRoom?>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith((ref) => controller.stream),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('u1')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 房间不存在显示已结束', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(null),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('u1')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.mic_off_outlined), findsOneWidget);
    expect(find.text('语音房已结束'), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 非参与者看到加入按钮', (tester) async {
    final room = _fakeRoom(
      hostId: 'host1',
      participants: ['host1', 'u2'],
      speakerIds: ['host1'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(room),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('outsider')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.text('加入'), findsOneWidget);
    expect(find.text('周末电影闲聊'), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 参与者看到离开按钮', (tester) async {
    final room = _fakeRoom(
      hostId: 'host1',
      participants: ['host1', 'u2'],
      speakerIds: ['host1'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(room),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('u2')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.text('离开'), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 主持人看到结束按钮', (tester) async {
    final room = _fakeRoom(
      hostId: 'host1',
      participants: ['host1', 'u2'],
      speakerIds: ['host1'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(room),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('host1')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.text('结束'), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 显示话题和音频即将上线', (tester) async {
    final room = _fakeRoom(topic: '一起聊周末计划');

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(room),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('outsider')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.text('一起聊周末计划'), findsOneWidget);
    expect(find.text('实时语音功能即将上线'), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 显示直播指示器', (tester) async {
    final room = _fakeRoom(isLive: true);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(room),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('outsider')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    expect(find.text('直播中'), findsOneWidget);
  });

  testWidgets('VoiceRoomDetailScreen —— 参与者网格渲染正确数量', (tester) async {
    final room = _fakeRoom(
      participants: ['host1', 'u2', 'u3', 'u4'],
      speakerIds: ['host1', 'u2'],
    );

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          voiceRoomProvider('r1').overrideWith(
            (ref) => Stream.value(room),
          ),
          authStateProvider.overrideWith(
            (ref) => Stream.value(_FakeUser('outsider')),
          ),
        ],
        child: const VoiceRoomDetailScreen(roomId: 'r1'),
      ),
    );
    await tester.pump();

    // 4 个参与者各有 CircleAvatar
    expect(find.byType(CircleAvatar), findsNWidgets(4 + 1)); // 4 in grid + 1 host avatar in info card
  });
}
