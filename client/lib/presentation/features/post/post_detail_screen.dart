import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/application.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/application_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/post_create_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/user_repository.dart';
import 'widgets/application_list_sheet.dart';
import 'widgets/apply_sheet.dart';

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postByIdProvider(postId));

    return postAsync.when(
      data: (post) => Scaffold(
        body: post == null ? _notFound(context) : _buildContent(context, post),
        bottomNavigationBar:
            post == null ? null : _BottomBar(post: post),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final gt = GlassTheme.of(context);
        return Scaffold(
          appBar: AppBar(),
          body: Center(
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
                    onPressed: () => ref.invalidate(postByIdProvider(postId)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _notFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('帖子不存在或已删除')),
    );
  }

  Widget _buildContent(BuildContext context, Post post) {
    final gt = GlassTheme.of(context);

    return GlowBackground(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: Colors.transparent,
            leading: CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
                tooltip: '返回',
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'post-${post.id}',
                child: post.images.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gt.colors.accent, gt.colors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: post.images.first,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: gt.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      post.category,
                      style: TextStyle(
                        color: gt.colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: gt.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _PublisherRow(userId: post.userId),
                  const SizedBox(height: 20),
                  // Info panel — GlassCard level:1
                  _buildInfoBox(context, post, gt),
                  const SizedBox(height: 20),
                  // Participants section — AvatarStack
                  _buildParticipantsSection(context, post, gt),
                  const SizedBox(height: 24),
                  if (post.description.isNotEmpty) ...[
                    Text(
                      '活动介绍',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: gt.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: gt.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, Post post, GlassThemeData gt) {
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoRow(
            Icons.schedule,
            '时间',
            post.time == null
                ? '待定'
                : DateFormat('yyyy年M月d日 HH:mm').format(post.time!),
            gt,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.location_on_outlined,
            '地点',
            post.location?.name ?? '待定',
            gt,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.payments_outlined,
            '费用',
            post.depositAmount > 0
                ? '${post.costType.label} · 押金 ¥${post.depositAmount}'
                : post.costType.label,
            gt,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.group_outlined,
            '人数',
            '${post.acceptedCount}/${post.totalSlots} 人',
            gt,
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(BuildContext context, Post post, GlassThemeData gt) {
    return Row(
      children: [
        Text(
          '参与者',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: gt.colors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        // TODO(data-model): Post model has no participantAvatarUrls field;
        // replace [] with post.participantAvatarUrls when the field is added.
        const AvatarStack(avatarUrls: [], size: 28),
        const Spacer(),
        Text(
          '${post.acceptedCount}/${post.totalSlots} 人',
          style: TextStyle(
            fontSize: 13,
            color: gt.colors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, GlassThemeData gt) {
    return Row(
      children: [
        Icon(icon, size: 18, color: gt.colors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: gt.colors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: gt.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 底部操作栏 —— 根据用户身份（作者/申请者）切换按钮。
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isOwner = uid != null && uid == post.userId;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: gt.colors.surface,
        border: Border(top: BorderSide(color: gt.colors.glassL1Border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: isOwner
            ? _OwnerButton(postId: post.id)
            : _ApplicantButtons(post: post),
      ),
    );
  }
}

class _OwnerButton extends ConsumerWidget {
  const _OwnerButton({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            label: '查看申请列表',
            icon: Icons.list_alt,
            variant: GlassButtonVariant.secondary,
            expand: true,
            onPressed: () => showApplicationListSheet(context, postId),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: gt.colors.textSecondary),
          onSelected: (action) => _handleAction(context, ref, action),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'cancel', child: Text('取消活动')),
            PopupMenuItem(
              value: 'delete',
              child: Text('删除帖子', style: TextStyle(color: gt.colors.error)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final gt = GlassTheme.of(context);
    if (action == 'cancel') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('取消活动'),
          content: const Text('取消后所有申请者会收到通知，确定取消吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('再想想')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: gt.colors.error),
              child: const Text('确定取消'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      try {
        await ref.read(postCreateRepositoryProvider).cancelPost(postId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('活动已取消')));
          context.pop();
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除帖子'),
          content: const Text('删除后不可恢复，确定吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: gt.colors.error),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      try {
        await ref.read(postCreateRepositoryProvider).deletePost(postId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('帖子已删除')));
          context.go('/');
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }
}

class _ApplicantButtons extends ConsumerWidget {
  const _ApplicantButtons({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAppAsync = ref.watch(myApplicationForPostProvider(post.id));
    final existing = myAppAsync.valueOrNull;

    String label;
    bool enabled;

    if (post.status == PostStatus.expired) {
      label = '活动已过期';
      enabled = false;
    } else if (post.status == PostStatus.cancelled) {
      label = '活动已取消';
      enabled = false;
    } else if (post.status == PostStatus.done) {
      label = '活动已结束';
      enabled = false;
    } else if (existing != null && existing.status.isActive) {
      // 已申请 — 显示状态 + 撤回按钮
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              label: '已申请 · ${existing.status.label}',
              onPressed: null,
              variant: GlassButtonVariant.ghost,
              expand: true,
            ),
          ),
          const SizedBox(width: 12),
          GlassButton(
            label: '撤回',
            onPressed: () => _handleWithdraw(context, ref, existing.id),
            variant: GlassButtonVariant.danger,
          ),
        ],
      );
    } else if (post.isFull) {
      label = '加入候补';
      enabled = true;
    } else {
      label = '立即申请';
      enabled = true;
    }

    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: label,
        enabled: enabled,
        child: GlassButton(
          label: label,
          onPressed: enabled ? () => _handleApply(context, ref) : null,
          variant: GlassButtonVariant.primary,
          expand: true,
        ),
      ),
    );
  }

  Future<void> _handleWithdraw(BuildContext context, WidgetRef ref, String applicationId) async {
    final gt = GlassTheme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤回申请'),
        content: const Text('确定撤回这条申请吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: gt.colors.error),
            child: const Text('撤回'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(applicationRepositoryProvider).withdrawApplication(applicationId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申请已撤回')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  Future<void> _handleApply(BuildContext context, WidgetRef ref) async {
    final result = await showApplySheet(context, post);
    if (result == null || !context.mounted) return;
    final msg = result.status == ApplicationStatus.waitlisted
        ? '已加入候补名单 ⏳'
        : '申请已发出，等待发布者回应 🎉';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 帖子详情页中展示发布者头像、昵称、评分，可跳转主页。
class _PublisherRow extends ConsumerWidget {
  const _PublisherRow({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final userAsync = ref.watch(userByIdProvider(userId));
    final user = userAsync.valueOrNull;
    if (user == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/user/$userId'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: gt.colors.glassL2Bg,
            backgroundImage: user.avatar.isNotEmpty
                ? CachedNetworkImageProvider(user.avatar)
                : null,
            child: user.avatar.isEmpty
                ? Icon(Icons.person, size: 18, color: gt.colors.textTertiary)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star, size: 13, color: gt.colors.starColor),
                    const SizedBox(width: 3),
                    Text(
                      '${user.rating.toStringAsFixed(1)} · ${user.reviewCount} 条评价',
                      style: TextStyle(
                        fontSize: 11,
                        color: gt.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: gt.colors.textTertiary),
        ],
      ),
    );
  }
}
