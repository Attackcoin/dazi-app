import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/dazi_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/post_create_repository.dart';
import '../../../data/repositories/post_repository.dart';
import 'widgets/chat_input_bar.dart';

/// 群聊页面。`chatId` 等于 postId —— 每个局一个群聊。
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .markRead(chatId: widget.chatId, uid: uid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePickImage(XFile image) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final user = ref.read(currentAppUserProvider).valueOrNull;
    try {
      final file = File(image.path);
      final url = await ref.read(postCreateRepositoryProvider).uploadImage(file);
      await ref.read(chatRepositoryProvider).sendImage(
            chatId: widget.chatId,
            senderId: uid,
            imageUrl: url,
            senderName: user?.name,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片发送失败：$e')),
        );
      }
    }
  }

  Future<void> _handleSend(String text) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final user = ref.read(currentAppUserProvider).valueOrNull;
    await ref.read(chatRepositoryProvider).sendText(
          chatId: widget.chatId,
          senderId: uid,
          text: text,
          senderName: user?.name,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final postAsync = ref.watch(postByIdProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    final post = postAsync.valueOrNull;
    final title = post?.title ?? '群聊';

    return Scaffold(
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: gt.colors.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (post != null)
              Text(
                '${post.acceptedCount}/${post.totalSlots} 人',
                style: TextStyle(
                  fontSize: 11,
                  color: gt.colors.textSecondary,
                ),
              ),
          ],
        ),
        titleSpacing: 4,
        actions: [
          // 查看局详情
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '活动详情',
            onPressed: () => context.push('/post/${widget.chatId}'),
          ),
        ],
      ),
      body: GlowBackground(
        child: Column(
          children: [
            // 活动时间横幅
            if (post?.time != null) _TimeBanner(time: post!.time!),
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  message: '消息加载失败，请重试',
                  onRetry: () =>
                      ref.invalidate(chatMessagesProvider(widget.chatId)),
                ),
                data: (messages) {
                  if (messages.isEmpty) return const _EmptyChat();
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == myUid;
                      final showTs = i == 0 ||
                          msg.timestamp - messages[i - 1].timestamp >
                              5 * 60 * 1000;
                      // 群聊中显示非自己的发送者名字
                      final showName = !isMe &&
                          (i == 0 || messages[i - 1].senderId != msg.senderId);
                      return _GroupMessageBubble(
                        message: msg,
                        isMe: isMe,
                        showTimestamp: showTs,
                        showSenderName: showName,
                        senderName: _getSenderName(msg),
                      );
                    },
                  );
                },
              ),
            ),
            ChatInputBar(onSend: _handleSend, onPickImage: _handlePickImage),
          ],
        ),
      ),
    );
  }

  /// 从消息冗余字段获取发送者名字，避免 N+1 Firestore 查询。
  String _getSenderName(ChatMessage msg) {
    // 优先用消息中存储的冗余字段
    if (msg.senderName != null && msg.senderName!.isNotEmpty) {
      return msg.senderName!;
    }
    // fallback：短 UID 截断显示
    return msg.senderId.length >= 6
        ? msg.senderId.substring(0, 6)
        : msg.senderId;
  }
}

/// 群聊气泡 —— 显示发送者昵称。
class _GroupMessageBubble extends StatelessWidget {
  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
    this.showTimestamp = false,
    this.showSenderName = false,
    this.senderName = '',
  });

  final ChatMessage message;
  final bool isMe;
  final bool showTimestamp;
  final bool showSenderName;
  final String senderName;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);

    if (message.type == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: gt.colors.glassL2Bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.text,
              style: TextStyle(fontSize: 11, color: gt.colors.textSecondary),
            ),
          ),
        ),
      );
    }

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
                style: TextStyle(fontSize: 11, color: gt.colors.textTertiary),
              ),
            ),
          ),
        if (showSenderName && !isMe)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 2),
            child: Text(
              senderName,
              style: TextStyle(
                fontSize: 11,
                color: gt.colors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            color: isMe ? null : gt.colors.glassL1Bg,
            gradient: isMe
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: DaziColors.heroGradientColors,
                  )
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 20),
            ),
            border: isMe
                ? null
                : Border.all(color: gt.colors.glassL1Border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: message.type == ChatMessageType.image && message.mediaUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(
                      width: 200,
                      height: 150,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                )
              : Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? Colors.white : gt.colors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
        ),
      ],
    );
  }
}

class _TimeBanner extends StatelessWidget {
  const _TimeBanner({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: gt.colors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: gt.colors.primary),
          const SizedBox(width: 8),
          Text(
            '活动时间：${DateFormat('M月d日 HH:mm').format(time)}',
            style: TextStyle(fontSize: 12, color: gt.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '群聊已创建，大家打个招呼吧~',
              style: TextStyle(color: gt.colors.textTertiary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
