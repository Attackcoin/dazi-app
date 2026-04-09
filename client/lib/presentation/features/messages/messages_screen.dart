import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/match_repository.dart';

/// 消息列表页 —— 展示当前用户所有搭子关系的最新消息。
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(myMatchesProvider);
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        centerTitle: false,
      ),
      body: matchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (matches) {
          if (matches.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 80,
              color: AppColors.border,
            ),
            itemBuilder: (_, i) =>
                _MatchTile(match: matches[i], myUid: myUid),
          );
        },
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.myUid});

  final AppMatch match;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final other = match.otherOf(myUid);
    final name = other?.name ?? match.postTitle;
    final avatar = other?.avatar ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.surfaceAlt,
        backgroundImage:
            avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
        child: avatar.isEmpty
            ? const Icon(Icons.person, color: AppColors.textTertiary)
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          match.lastMessagePreview ?? '快去打个招呼吧～',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _formatTime(match.lastMessageAt),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          _CategoryTag(category: match.postCategory),
        ],
      ),
      onTap: () => context.push('/chat/${match.id}'),
    );
  }

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return DateFormat('HH:mm').format(t);
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('M月d日').format(t);
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    if (category.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💬', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            '还没有消息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            '去广场找个搭子吧～',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
