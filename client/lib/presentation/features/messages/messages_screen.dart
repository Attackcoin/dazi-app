import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/match_repository.dart';

/// 消息列表页 —— 展示当前用户加入的所有局的群聊。
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(myMatchesProvider);
    final gt = GlassTheme.of(context);

    return Scaffold(
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: gt.colors.surface,
        title: const Text('消息'),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: GlowBackground(
        child: matchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: gt.colors.textTertiary),
                  const SizedBox(height: 12),
                  Text('加载失败：$e', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(myMatchesProvider),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          data: (matches) {
            if (matches.isEmpty) return const _EmptyState();

            // 按 postId 分组 —— 一个局只显示一条
            final seen = <String>{};
            final grouped = <AppMatch>[];
            for (final m in matches) {
              if (seen.add(m.postId)) {
                grouped.add(m);
              }
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: grouped.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 80,
                color: gt.colors.glassL1Border,
              ),
              itemBuilder: (_, i) => AnimatedListItem(
                index: i,
                child: _GroupChatTile(match: grouped[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GroupChatTile extends StatelessWidget {
  const _GroupChatTile({required this.match});

  final AppMatch match;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final memberCount = match.participants.length;

    return GlassCard(
      level: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gt.colors.primary, gt.colors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              _categoryEmoji(match.postCategory),
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Text(
          match.postTitle.isNotEmpty ? match.postTitle : '搭子群聊',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: gt.colors.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 13, color: gt.colors.textTertiary),
              const SizedBox(width: 3),
              Text(
                '$memberCount人',
                style: TextStyle(
                  fontSize: 11,
                  color: gt.colors.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  match.lastMessagePreview ?? '快去打个招呼吧~',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: gt.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatTime(match.lastMessageAt),
              style: TextStyle(
                fontSize: 11,
                color: gt.colors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            _CategoryTag(category: match.postCategory),
          ],
        ),
        // 用 postId 作为群聊 chatId
        onTap: () => context.push('/chat/${match.postId}'),
      ),
    );
  }

  String _categoryEmoji(String cat) {
    if (cat.contains('吃') || cat.contains('喝') || cat.contains('火锅')) return '🍜';
    if (cat.contains('运动') || cat.contains('健身')) return '🏃';
    if (cat.contains('游戏') || cat.contains('娱乐')) return '🎮';
    if (cat.contains('旅') || cat.contains('出行')) return '✈️';
    if (cat.contains('学') || cat.contains('读书')) return '📚';
    return '🎉';
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
    final gt = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: gt.colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          color: gt.colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState();

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> with SingleTickerProviderStateMixin {
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _floatAnim,
            builder: (context, child) {
              final dy = _floatAnim.value * 8.0 - 4.0; // oscillate -4 to +4
              return Transform.translate(
                offset: Offset(0, dy),
                child: child,
              );
            },
            child: const Text('💬', style: TextStyle(fontSize: 56)),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有群聊',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: gt.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '滑一滑加入一个局吧~',
            style: TextStyle(fontSize: 13, color: gt.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
