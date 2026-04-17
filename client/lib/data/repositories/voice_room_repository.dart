import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/region_config.dart';
import '../models/voice_room.dart';
import 'auth_repository.dart';

final voiceRoomRepositoryProvider = Provider<VoiceRoomRepository>((ref) {
  final region = RegionConfig.resolveFunctionsRegion();
  return VoiceRoomRepository(
    firestore: ref.watch(firestoreProvider),
    functions: FirebaseFunctions.instanceFor(region: region),
  );
});

class VoiceRoomRepository {
  VoiceRoomRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// 获取进行中的语音房列表（Firestore 直读）。
  Stream<List<VoiceRoom>> watchLiveRooms({int limit = 20}) {
    return _firestore
        .collection('voiceRooms')
        .where('isLive', isEqualTo: true)
        .orderBy('participantCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => VoiceRoom.fromFirestore(d)).toList());
  }

  /// 获取单个语音房详情。
  Stream<VoiceRoom?> watchRoom(String roomId) {
    return _firestore
        .collection('voiceRooms')
        .doc(roomId)
        .snapshots()
        .map((snap) => snap.exists ? VoiceRoom.fromFirestore(snap) : null);
  }

  /// 创建语音房。
  Future<String> createRoom({
    required String title,
    String topic = '',
    String category = '',
    int maxParticipants = 8,
  }) async {
    final callable = _functions.httpsCallable('createVoiceRoom');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'title': title,
      'topic': topic,
      'category': category,
      'maxParticipants': maxParticipants,
    });
    return resp.data['roomId'] as String;
  }

  /// 加入语音房。
  Future<void> joinRoom(String roomId) async {
    final callable = _functions.httpsCallable('joinVoiceRoom');
    await callable.call<Map<dynamic, dynamic>>({'roomId': roomId});
  }

  /// 离开语音房。
  Future<void> leaveRoom(String roomId) async {
    final callable = _functions.httpsCallable('leaveVoiceRoom');
    await callable.call<Map<dynamic, dynamic>>({'roomId': roomId});
  }

  /// 结束语音房（仅主持人）。
  Future<void> endRoom(String roomId) async {
    final callable = _functions.httpsCallable('endVoiceRoom');
    await callable.call<Map<dynamic, dynamic>>({'roomId': roomId});
  }
}

// ─── Riverpod providers ─────────────────────────────

/// 进行中的语音房列表流。
final liveVoiceRoomsProvider = StreamProvider<List<VoiceRoom>>((ref) {
  return ref.watch(voiceRoomRepositoryProvider).watchLiveRooms();
});

/// 单个语音房详情流。
final voiceRoomProvider =
    StreamProvider.family<VoiceRoom?, String>((ref, roomId) {
  return ref.watch(voiceRoomRepositoryProvider).watchRoom(roomId);
});
