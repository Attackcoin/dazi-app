import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/models/application.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/application_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/post_create_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/user_repository.dart';
import 'widgets/application_list_sheet.dart';
import 'widgets/apply_sheet.dart';

String _costTypeLabel(AppLocalizations l10n, CostType t) => switch (t) {
  CostType.aa => l10n.costType_aa,
  CostType.host => l10n.costType_host,
  CostType.self => l10n.costType_self,
  CostType.tbd => l10n.costType_tbd,
};

String _applicationStatusLabel(AppLocalizations l10n, ApplicationStatus s) => switch (s) {
  ApplicationStatus.pending => l10n.applicationList_statusPending,
  ApplicationStatus.accepted => l10n.applicationList_statusAccepted,
  ApplicationStatus.rejected => l10n.applicationList_statusRejected,
  ApplicationStatus.waitlisted => l10n.applicationList_statusWaitlisted,
  ApplicationStatus.expired => l10n.applicationList_statusExpired,
  ApplicationStatus.cancelled => l10n.applicationList_statusCancelled,
};

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
        return Scaffold(
          appBar: AppBar(),
          body: ErrorRetryView(
            error: e,
            onRetry: () => ref.invalidate(postByIdProvider(postId)),
          ),
        );
      },
    );
  }

  static const _hostingDomain = 'dazi-prod-9c9d6.web.app';

  void _sharePost(BuildContext context, Post post) {
    final l10n = AppLocalizations.of(context)!;
    final url = 'https://$_hostingDomain/p/${post.id}';
    final timePart = post.time != null
        ? '\n${DateFormat('M/d HH:mm').format(post.time!)}'
        : '';
    final locationPart = post.location?.name.isNotEmpty == true
        ? '\n${post.location!.name}'
        : '';
    final text = '${post.title}$timePart$locationPart\n\n${l10n.share_postMessage}\n$url';
    SharePlus.instance.share(ShareParams(text: text));
  }

  Widget _notFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(AppLocalizations.of(context)!.postDetail_notFound)),
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
            actions: [
              CircleAvatar(
                backgroundColor: Colors.black38,
                child: IconButton(
                  icon: const Icon(Icons.share, color: Colors.white, size: 18),
                  tooltip: AppLocalizations.of(context)!.share_button,
                  onPressed: () => _sharePost(context, post),
                ),
              ),
              const SizedBox(width: 8),
            ],
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
                        memCacheWidth: 800,
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
                  if (post.isSeries) ...[
                    const SizedBox(height: 12),
                    _SeriesInfoSection(post: post),
                  ],
                  if (post.depositAmount > 0) ...[
                    const SizedBox(height: 12),
                    _buildDepositBanner(context, post, gt),
                  ],
                  const SizedBox(height: 20),
                  // Participants section — AvatarStack
                  _buildParticipantsSection(context, post, gt),
                  const SizedBox(height: 24),
                  if (post.description.isNotEmpty) ...[
                    Text(
                      AppLocalizations.of(context)!.postDetail_activityDescription,
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
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoRow(
            Icons.schedule,
            l10n.postDetail_timeLabel,
            post.time == null
                ? l10n.common_tbd
                : DateFormat('yyyy-MM-dd HH:mm').format(post.time!),
            gt,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.location_on_outlined,
            l10n.postDetail_placeLabel,
            post.location?.name ?? l10n.common_tbd,
            gt,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.payments_outlined,
            l10n.postDetail_costLabel,
            post.depositAmount > 0
                ? l10n.postDetail_costWithDeposit(_costTypeLabel(l10n, post.costType), post.depositAmount)
                : _costTypeLabel(l10n, post.costType),
            gt,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.group_outlined,
            l10n.postDetail_slotsLabel,
            l10n.postDetail_peopleCount(post.acceptedCount, post.totalSlots),
            gt,
          ),
        ],
      ),
    );
  }

  Widget _buildDepositBanner(BuildContext context, Post post, GlassThemeData gt) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 2,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: gt.colors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.shield_outlined, size: 20, color: gt.colors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.postDetail_depositBadge(post.depositAmount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.postDetail_depositDescription,
                  style: TextStyle(
                    fontSize: 11,
                    color: gt.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(BuildContext context, Post post, GlassThemeData gt) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Text(
          l10n.postDetail_participants,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: gt.colors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        const AvatarStack(avatarUrls: [], size: 28),
        const Spacer(),
        Text(
          l10n.postDetail_peopleCount(post.acceptedCount, post.totalSlots),
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
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: GlassButton(
            label: l10n.postDetail_viewApplications,
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
            PopupMenuItem(value: 'cancel', child: Text(l10n.postDetail_cancelActivity)),
            PopupMenuItem(
              value: 'delete',
              child: Text(l10n.postDetail_deletePost, style: TextStyle(color: gt.colors.error)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (action == 'cancel') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.postDetail_cancelActivity),
          content: Text(l10n.postDetail_cancelConfirmContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.postDetail_cancelRethink)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: gt.colors.error),
              child: Text(l10n.postDetail_cancelConfirmButton),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      try {
        await ref.read(postCreateRepositoryProvider).cancelPost(postId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.postDetail_cancelled)));
          context.pop();
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.common_actionFailed('$e'))));
      }
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.postDetail_deletePost),
          content: Text(l10n.postDetail_deleteConfirmContent),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.common_cancel)),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: gt.colors.error),
              child: Text(l10n.postDetail_deleteConfirmButton),
            ),
          ],
        ),
      );
      if (confirm != true || !context.mounted) return;
      try {
        await ref.read(postCreateRepositoryProvider).deletePost(postId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.postDetail_deleted)));
          context.go('/');
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.common_actionFailed('$e'))));
      }
    }
  }
}

class _ApplicantButtons extends ConsumerWidget {
  const _ApplicantButtons({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myAppAsync = ref.watch(myApplicationForPostProvider(post.id));
    final existing = myAppAsync.valueOrNull;

    String label;
    bool enabled;

    if (post.status == PostStatus.expired) {
      label = l10n.postDetail_activityExpired;
      enabled = false;
    } else if (post.status == PostStatus.cancelled) {
      label = l10n.postDetail_activityCancelled;
      enabled = false;
    } else if (post.status == PostStatus.done) {
      label = l10n.postDetail_activityDone;
      enabled = false;
    } else if (existing != null && existing.status.isActive) {
      return Row(
        children: [
          Expanded(
            child: GlassButton(
              label: l10n.postDetail_statusApplied(_applicationStatusLabel(l10n, existing.status)),
              onPressed: null,
              variant: GlassButtonVariant.ghost,
              expand: true,
            ),
          ),
          const SizedBox(width: 12),
          GlassButton(
            label: l10n.postDetail_withdrawApplication,
            onPressed: () => _handleWithdraw(context, ref, existing.id),
            variant: GlassButtonVariant.danger,
          ),
        ],
      );
    } else if (post.isFull) {
      label = l10n.postDetail_joinWaitlist;
      enabled = true;
    } else {
      label = l10n.postDetail_applyNow;
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
        title: Text(AppLocalizations.of(context)!.postDetail_withdrawConfirmTitle),
        content: Text(AppLocalizations.of(context)!.postDetail_withdrawConfirmContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.common_cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: gt.colors.error),
            child: Text(AppLocalizations.of(context)!.postDetail_withdrawApplication),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(applicationRepositoryProvider).withdrawApplication(applicationId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.postDetail_withdrawn)));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.common_actionFailed('$e'))));
    }
  }

  Future<void> _handleApply(BuildContext context, WidgetRef ref) async {
    final result = await showApplySheet(context, post);
    if (result == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final msg = result.status == ApplicationStatus.waitlisted
        ? l10n.postDetail_applicationWaitlisted
        : l10n.postDetail_applicationSent;
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: gt.colors.textPrimary,
                        ),
                      ),
                    ),
                    if (user.verificationLevel >= 2) ...[
                      const SizedBox(width: 4),
                      _VerifiedIcon(gt: gt),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.star, size: 13, color: gt.colors.starColor),
                    const SizedBox(width: 3),
                    Text(
                      '${user.rating.toStringAsFixed(1)} · ${AppLocalizations.of(context)!.postDetail_reviewCount(user.reviewCount)}',
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

/// 系列活动信息区域 —— 显示频率、当前周数/总周数 + 可展开的"其他期次"列表。
class _SeriesInfoSection extends ConsumerStatefulWidget {
  const _SeriesInfoSection({required this.post});

  final Post post;

  @override
  ConsumerState<_SeriesInfoSection> createState() => _SeriesInfoSectionState();
}

class _SeriesInfoSectionState extends ConsumerState<_SeriesInfoSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final post = widget.post;
    final l10n = AppLocalizations.of(context)!;

    final recurrenceLabel = post.recurrence == 'biweekly'
        ? l10n.post_seriesRecurrenceBiweekly
        : l10n.post_seriesRecurrenceWeekly;

    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: gt.colors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_repeat, size: 20, color: gt.colors.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l10n.post_seriesActivity,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: gt.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PillTag(
                          label: l10n.post_seriesWeekOf(
                            post.seriesWeek ?? 1,
                            post.seriesTotalWeeks ?? 1,
                          ),
                          color: gt.colors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      recurrenceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: gt.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.seriesId != null && post.seriesId!.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    _expanded
                        ? l10n.post_seriesOtherWeeks
                        : l10n.post_viewFullSeries,
                    style: TextStyle(
                      fontSize: 13,
                      color: gt.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: gt.colors.primary,
                  ),
                ],
              ),
            ),
            if (_expanded) _buildSeriesList(context, post, gt, l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildSeriesList(
    BuildContext context,
    Post currentPost,
    GlassThemeData gt,
    AppLocalizations l10n,
  ) {
    final seriesAsync = ref.watch(seriesPostsProvider(currentPost.seriesId!));
    return seriesAsync.when(
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: posts.map((p) {
              final isCurrent = p.id == currentPost.id;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: isCurrent
                      ? gt.colors.primary.withValues(alpha: 0.15)
                      : gt.colors.glassL1Bg,
                  child: Text(
                    '${p.seriesWeek ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? gt.colors.primary
                          : gt.colors.textSecondary,
                    ),
                  ),
                ),
                title: Text(
                  p.time == null
                      ? l10n.common_timeTbd
                      : DateFormat('M/d HH:mm').format(p.time!),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                    color: gt.colors.textPrimary,
                  ),
                ),
                trailing: PillTag(
                  label: _statusLabel(l10n, p.status),
                  color: _statusColor(gt, p.status),
                ),
                onTap: isCurrent
                    ? null
                    : () => context.push('/post/${p.id}'),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _statusLabel(AppLocalizations l10n, PostStatus s) => switch (s) {
    PostStatus.open => l10n.postStatus_open,
    PostStatus.full => l10n.postStatus_full,
    PostStatus.done => l10n.postStatus_done,
    PostStatus.cancelled => l10n.postStatus_cancelled,
    PostStatus.expired => l10n.postStatus_expired,
  };

  Color _statusColor(GlassThemeData gt, PostStatus s) => switch (s) {
    PostStatus.open => gt.colors.success,
    PostStatus.full => gt.colors.info,
    PostStatus.done => gt.colors.textTertiary,
    PostStatus.cancelled => gt.colors.error,
    PostStatus.expired => gt.colors.textTertiary,
  };
}

/// 已验证小图标 — 蓝色 verified_user。
class _VerifiedIcon extends StatelessWidget {
  const _VerifiedIcon({required this.gt});

  final GlassThemeData gt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.post_verifiedPublisher,
      child: Icon(Icons.verified_user, size: 15, color: gt.colors.info),
    );
  }
}
