part of 'profile_screen.dart';

// ============================================================
// 分区：我发布的 / 我申请的 / 参加过
// ============================================================

class _MyPostsTab extends ConsumerWidget {
  const _MyPostsTab({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(postsByUserProvider(uid));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: l10n.common_loadFailedWithError('$e'),
        onRetry: () => ref.invalidate(postsByUserProvider(uid)),
      ),
      data: (list) {
        if (list.isEmpty) return _EmptyState(text: l10n.profile_noPosts);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => AnimatedListItem(
            index: i,
            child: _PostItem(post: list[i]),
          ),
        );
      },
    );
  }
}

class _PostItem extends StatelessWidget {
  const _PostItem({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return GlassCard(
      level: 1,
      onTap: () => context.push('/post/${post.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: gt.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              post.category,
              style: TextStyle(
                  fontSize: 11,
                  color: gt.colors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gt.colors.textPrimary),
            ),
          ),
          Text(
            _postStatusLabel(AppLocalizations.of(context)!, post.status),
            style: TextStyle(
                fontSize: 11, color: gt.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

String _postStatusLabel(AppLocalizations l10n, PostStatus s) => switch (s) {
      PostStatus.open => l10n.postStatus_open,
      PostStatus.full => l10n.postStatus_full,
      PostStatus.done => l10n.postStatus_done,
      PostStatus.cancelled => l10n.postStatus_cancelled,
      PostStatus.expired => l10n.postStatus_expired,
    };

class _MyApplicationsTab extends ConsumerWidget {
  const _MyApplicationsTab({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(applicationsByApplicantProvider(uid));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(
        message: l10n.common_loadFailedWithError('$e'),
        onRetry: () => ref.invalidate(applicationsByApplicantProvider(uid)),
      ),
      data: (list) {
        if (list.isEmpty) return _EmptyState(text: l10n.profile_noApplications);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => AnimatedListItem(
            index: i,
            child: _ApplicationItem(app: list[i]),
          ),
        );
      },
    );
  }
}

class _ApplicationItem extends StatelessWidget {
  const _ApplicationItem({required this.app});
  final Application app;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return GlassCard(
      level: 1,
      onTap: () => context.push('/post/${app.postId}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.assignment_outlined,
              size: 18, color: gt.colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '申请 #${app.postId.substring(0, app.postId.length.clamp(0, 6))}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gt.colors.textPrimary),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(gt, app.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _applicationStatusLabel(AppLocalizations.of(context)!, app.status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(gt, app.status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _applicationStatusLabel(AppLocalizations l10n, ApplicationStatus s) => switch (s) {
        ApplicationStatus.pending => l10n.applicationList_statusPending,
        ApplicationStatus.accepted => l10n.applicationList_statusAccepted,
        ApplicationStatus.rejected => l10n.applicationList_statusRejected,
        ApplicationStatus.waitlisted => l10n.applicationList_statusWaitlisted,
        ApplicationStatus.expired => l10n.applicationList_statusExpired,
        ApplicationStatus.cancelled => l10n.applicationList_statusCancelled,
      };

  Color _statusColor(GlassThemeData gt, ApplicationStatus s) => switch (s) {
        ApplicationStatus.accepted => gt.colors.success,
        ApplicationStatus.rejected => gt.colors.error,
        ApplicationStatus.expired ||
        ApplicationStatus.cancelled =>
          gt.colors.textTertiary,
        _ => gt.colors.warning,
      };
}

/// 参加过分区 —— 因不改 match 相关代码，暂基于 totalMeetups 摘要展示。
class _JoinedTab extends StatelessWidget {
  const _JoinedTab({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (user.totalMeetups == 0) {
      return _EmptyState(text: l10n.profile_noJoined);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            level: 1,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined, color: gt.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.profile_joinedCount(user.totalMeetups),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          if (user.badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(l10n.profile_badges),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.badges
                  .map((b) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: gt.colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: gt.colors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 12,
                            color: gt.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
