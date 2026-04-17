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

/// 群聊消息读写 —— 每个局（post）一个群聊。
///
/// 消息存储在 Firebase Realtime Database：`chats/{postId}/messages/{msgId}`
/// 最后消息摘要同步到 Firestore `posts/{postId}` 便于消息列表展示。
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

  /// 发送一条文字消息。同时更新该群聊关联的 match 文档的消息摘要。
  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String text,
    String? senderName,
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

    // 同步更新 match 文档的消息摘要（消息列表展示用）。
    // chatId == postId，查发送者参与的 match 文档并更新。
    // 其他参与者的 match 由 Cloud Function onNewChatMessage 触发器统一更新。
    final preview = senderName != null
        ? '$senderName: ${trimmed.length > 30 ? '${trimmed.substring(0, 30)}…' : trimmed}'
        : trimmed.length > 40 ? '${trimmed.substring(0, 40)}…' : trimmed;

    await _updateMatchPreviews(
      postId: chatId,
      senderId: senderId,
      now: now,
      preview: preview,
    );
  }

  /// 发送一条图片消息。
  Future<void> sendImage({
    required String chatId,
    required String senderId,
    required String imageUrl,
    String? senderName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final msg = ChatMessage(
      id: '',
      senderId: senderId,
      type: ChatMessageType.image,
      text: '',
      mediaUrl: imageUrl,
      lat: null,
      lng: null,
      timestamp: now,
      readBy: {senderId: true},
    );

    await _messagesRef(chatId).push().set(msg.toMap());

    final preview = senderName != null ? '$senderName: [图片]' : '[图片]';
    await _updateMatchPreviews(
      postId: chatId,
      senderId: senderId,
      now: now,
      preview: preview,
    );
  }

  /// 更新发送者参与的 match 文档的消息摘要。
  /// Firestore rules 允许参与者更新 lastMessageAt / lastMessagePreview。
  Future<void> _updateMatchPreviews({
    required String postId,
    required String senderId,
    required int now,
    required String preview,
  }) async {
    final matchesSnap = await _firestore
        .collection('matches')
        .where('postId', isEqualTo: postId)
        .where('participants', arrayContains: senderId)
        .get();
    for (final doc in matchesSnap.docs) {
      await doc.reference.update({
        'lastMessageAt': Timestamp.fromMillisecondsSinceEpoch(now),
        'lastMessagePreview': preview,
      });
    }
  }

  /// 标记当前用户已读最新消息。
  /// 同时更新 Firestore match 文档的 lastReadAt.{uid}，用于驱动未读 badge。
  Future<void> markRead({
    required String chatId,
    required String uid,
  }) async {
    // 1) RTDB：标记消息 readBy
    final snap = await _messagesRef(chatId).orderByChild('timestamp').limitToLast(20).get();
    final raw = snap.value;
    if (raw is Map) {
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

    // 2) Firestore：更新 match.lastReadAt.{uid}
    final matchesSnap = await _firestore
        .collection('matches')
        .where('postId', isEqualTo: chatId)
        .where('participants', arrayContains: uid)
        .limit(1)
        .get();
    for (final doc in matchesSnap.docs) {
      await doc.reference.update({
        'lastReadAt.$uid': FieldValue.serverTimestamp(),
      });
    }
  }
}

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).watchMessages(chatId);
});
