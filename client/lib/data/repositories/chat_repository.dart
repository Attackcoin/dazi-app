import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import 'auth_repository.dart';

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    database: ref.watch(firebaseDatabaseProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// 聊天消息读写 —— 存储在 Firebase Realtime Database。
///
/// 路径：`chats/{chatId}/messages/{msgId}`
class ChatRepository {
  ChatRepository({
    required FirebaseDatabase database,
    required FirebaseFirestore firestore,
  })  : _db = database,
        _firestore = firestore;

  final FirebaseDatabase _db;
  final FirebaseFirestore _firestore;

  DatabaseReference _messagesRef(String chatId) =>
      _db.ref('chats/$chatId/messages');

  /// 监听最近 100 条消息，按时间升序返回。
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    final query = _messagesRef(chatId).orderByChild('timestamp').limitToLast(100);
    return query.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return const <ChatMessage>[];
      final list = <ChatMessage>[];
      raw.forEach((key, value) {
        if (value is Map) {
          list.add(ChatMessage.fromMap(key as String, value));
        }
      });
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// 发送一条文字消息。同时更新 matches/{chatId} 的 lastMessage 字段。
  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final msg = ChatMessage(
      id: '',
      senderId: senderId,
      type: ChatMessageType.text,
      text: trimmed,
      mediaUrl: null,
      lat: null,
      lng: null,
      timestamp: now,
      readBy: {senderId: true},
    );

    await _messagesRef(chatId).push().set(msg.toMap());

    // 同步更新 match 的最后消息字段（用于消息列表展示）。
    await _firestore.collection('matches').doc(chatId).set({
      'lastMessageAt': Timestamp.fromMillisecondsSinceEpoch(now),
      'lastMessagePreview': trimmed.length > 40
          ? '${trimmed.substring(0, 40)}…'
          : trimmed,
    }, SetOptions(merge: true));
  }

  /// 标记当前用户已读最新消息（轻量写入）。
  Future<void> markRead({
    required String chatId,
    required String uid,
  }) async {
    final snap = await _messagesRef(chatId).orderByChild('timestamp').limitToLast(20).get();
    final raw = snap.value;
    if (raw is! Map) return;
    final updates = <String, Object?>{};
    raw.forEach((key, value) {
      if (value is Map) {
        updates['$key/readBy/$uid'] = true;
      }
    });
    if (updates.isNotEmpty) {
      await _messagesRef(chatId).update(updates);
    }
  }
}

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});
