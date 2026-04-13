/// 聊天消息模型 —— 对应 Realtime DB `chats/{chatId}/messages/{msgId}`。
class ChatMessage {
  final String id;
  final String senderId;
  /// 发送时写入的发送者昵称冗余字段，避免 N+1 查询 Firestore users 集合。
  final String? senderName;
  final ChatMessageType type;
  final String text;
  final String? mediaUrl;
  final double? lat;
  final double? lng;
  final int timestamp; // epoch millis
  final Map<String, bool> readBy;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.type,
    required this.text,
    required this.mediaUrl,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.readBy,
  });

  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory ChatMessage.fromMap(String id, Map<dynamic, dynamic> m) {
    final readByRaw = m['readBy'];
    final readBy = <String, bool>{};
    if (readByRaw is Map) {
      readByRaw.forEach((k, v) {
        if (k is String && v is bool) readBy[k] = v;
      });
    }
    return ChatMessage(
      id: id,
      senderId: m['senderId'] as String? ?? '',
      senderName: m['senderName'] as String?,
      type: ChatMessageType.fromString(m['type'] as String?),
      text: m['text'] as String? ?? '',
      mediaUrl: m['mediaUrl'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      timestamp: (m['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      readBy: readBy,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        if (senderName != null) 'senderName': senderName,
        'type': type.value,
        'text': text,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'timestamp': timestamp,
        'readBy': readBy,
      };
}

enum ChatMessageType {
  text('text'),
  image('image'),
  voice('voice'),
  location('location'),
  system('system');

  final String value;
  const ChatMessageType(this.value);

  static ChatMessageType fromString(String? v) => ChatMessageType.values
      .firstWhere((e) => e.value == v, orElse: () => ChatMessageType.text);
}
