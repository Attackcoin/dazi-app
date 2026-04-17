import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/voice_room.dart';
import 'package:dazi_app/data/repositories/voice_room_repository.dart';
import 'package:dazi_app/presentation/features/voice/voice_rooms_screen.dart';
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
  String id = 'r1',
  String title = '周末电影闲聊',
  String topic = '聊聊最近好看的电影',
  String hostName = '张三',
  int participantCount = 3,
  int maxParticipants = 8,
  bool isLive = true,
}) =>
    VoiceRoom(
      id: id,
      title: title,
      topic: topic,
      category: '影视',
      hostId: 'u1',
      hostName: hostName,
      hostAvatar: '',
      maxParticipants: maxParticipants,
      participants: List.generate(participantCount, (i) => 'u$i'),
      speakerIds: const ['u1'],
      participantCount: participantCount,
      isLive: isLive,
    );

void main() {
  testWidgets('VoiceRoomsScreen —— loading 态显示进度指示器', (tester) async {
    final controller = StreamController<List<VoiceRoom>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          liveVoiceRoomsProvider.overrideWith((ref) => controller.stream),
        ],
        child: const VoiceRoomsScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('VoiceRoomsScreen —— 空列表显示空态图标', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          liveVoiceRoomsProvider.overrideWith(
            (ref) => Stream.value(<VoiceRoom>[]),
          ),
        ],
        child: const VoiceRoomsScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.mic_off_outlined), findsOneWidget);
  });

  testWidgets('VoiceRoomsScreen —— 有数据时显示房间卡片', (tester) async {
    final rooms = [
      _fakeRoom(id: 'r1', title: '周末电影闲聊', participantCount: 3),
      _fakeRoom(id: 'r2', title: '跑步打卡群', participantCount: 5),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          liveVoiceRoomsProvider.overrideWith(
            (ref) => Stream.value(rooms),
          ),
        ],
        child: const VoiceRoomsScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('周末电影闲聊'), findsOneWidget);
    expect(find.text('跑步打卡群'), findsOneWidget);
    // 人数 badge
    expect(find.text('3/8人'), findsOneWidget);
    expect(find.text('5/8人'), findsOneWidget);
  });

  testWidgets('VoiceRoomsScreen —— 错误态显示加载失败', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          liveVoiceRoomsProvider.overrideWith(
            (ref) => Stream<List<VoiceRoom>>.error(Exception('network')),
          ),
        ],
        child: const VoiceRoomsScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('VoiceRoomsScreen —— 卡片显示话题和主持人', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          liveVoiceRoomsProvider.overrideWith(
            (ref) => Stream.value([
              _fakeRoom(topic: '一起聊周末计划', hostName: '李四'),
            ]),
          ),
        ],
        child: const VoiceRoomsScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('一起聊周末计划'), findsOneWidget);
    expect(find.text('李四'), findsOneWidget);
  });

  testWidgets('VoiceRoomsScreen —— 创建按钮存在', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          liveVoiceRoomsProvider.overrideWith(
            (ref) => Stream.value(<VoiceRoom>[]),
          ),
        ],
        child: const VoiceRoomsScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });
}
