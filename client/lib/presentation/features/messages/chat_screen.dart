import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../../../data/repositories/match_repository.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';

/// 单个搭子聊天页。`chatId` 等于 match 文档 id。
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
    // 进入聊天后标记已读（异步，不阻塞 UI）
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .markRead(chatId: widget.chatId, uid: uid);
    } catch (_) {
      // 静默失败
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(String text) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(chatRepositoryProvider).sendText(
          chatId: widget.chatId,
          senderId: uid,
          text: text,
        );
    // 发送后滚到底部
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
    final matchAsync = ref.watch(matchByIdProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    final match = matchAsync.valueOrNull;
    final other = match?.otherOf(myUid);
    final title = other?.name ?? '聊天';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceAlt,
              backgroundImage: (other?.avatar.isNotEmpty ?? false)
                  ? CachedNetworkImageProvider(other!.avatar)
                  : null,
              child: (other?.avatar.isEmpty ?? true)
                  ? const Icon(Icons.person, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (match != null && match.postTitle.isNotEmpty)
                    Text(
                      match.postTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.error_outline, color: AppColors.primary),
            tooltip: '紧急求助',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('紧急求助功能待接入')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (match != null) _MeetupBanner(match: match),
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('消息加载失败：$e')),
              data: (messages) {
                if (messages.isEmpty) return const _EmptyChat();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final showTs = i == 0 ||
                        msg.timestamp - messages[i - 1].timestamp >
                            5 * 60 * 1000;
                    return MessageBubble(
                      message: msg,
                      isMe: msg.senderId == myUid,
                      showTimestamp: showTs,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(onSend: _handleSend),
        ],
      ),
    );
  }
}

class _MeetupBanner extends StatelessWidget {
  const _MeetupBanner({required this.match});

  final AppMatch match;

  @override
  Widget build(BuildContext context) {
    if (match.postTime == null) return const SizedBox.shrink();
    final time = match.postTime!;
    final isToday = DateUtils.isSameDay(time, DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.schedule, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '活动时间：${DateFormat('M月d日 HH:mm').format(time)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (isToday)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('签到功能待接入 Step 5')),
                );
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '开始签到',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '打个招呼开始聊天吧～',
          style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
        ),
      ),
    );
  }
}
