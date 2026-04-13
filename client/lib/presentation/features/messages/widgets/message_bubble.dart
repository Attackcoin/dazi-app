import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../data/models/chat_message.dart';

/// 聊天气泡 —— 区分发送方/接收方，支持文字消息。
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTimestamp = false,
  });

  final ChatMessage message;
  final bool isMe;
  final bool showTimestamp;

  @override
  Widget build(BuildContext context) {
    if (message.type == ChatMessageType.system) {
      return _SystemNotice(text: message.text);
    }

    final colors = GlassTheme.of(context).colors;
    final bubbleColor = isMe ? colors.primary : colors.glassL1Bg;
    final textColor = isMe ? Colors.white : colors.textPrimary;

    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showTimestamp)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                DateFormat('M月d日 HH:mm').format(message.sentAt),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
          ),
          child: Text(
            message.text,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemNotice extends StatelessWidget {
  const _SystemNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = GlassTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.glassL1Bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
