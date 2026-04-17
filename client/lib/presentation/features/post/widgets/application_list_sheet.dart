import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../../data/models/app_user.dart';
import '../../../../data/models/application.dart';
import '../../../../data/repositories/application_repository.dart';
import '../../../../data/repositories/auth_repository.dart';

/// 发布者视角：查看并管理某个 post 的申请列表。
class ApplicationListSheet extends ConsumerWidget {
  const ApplicationListSheet({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(applicationsForPostProvider(postId));
    final colors = GlassTheme.of(context).colors;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.glassL1Border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                AppLocalizations.of(context)!.applicationList_title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: appsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetryView(
                  error: e,
                  onRetry: () =>
                      ref.invalidate(applicationsForPostProvider(postId)),
                ),
                data: (apps) {
                  if (apps.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.applicationList_emptyHint,
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: apps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ApplicationTile(app: apps[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTile extends ConsumerStatefulWidget {
  const _ApplicationTile({required this.app});

  final Application app;

  @override
  ConsumerState<_ApplicationTile> createState() => _ApplicationTileState();
}

class _ApplicationTileState extends ConsumerState<_ApplicationTile> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationRepositoryProvider)
          .acceptApplication(widget.app.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.applicationList_accepted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.applicationList_actionFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(applicationRepositoryProvider)
          .rejectApplication(widget.app.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.applicationList_rejected)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.applicationList_actionFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);
    final colors = GlassTheme.of(context).colors;
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore.collection('users').doc(widget.app.applicantId).get(),
      builder: (context, snap) {
        final user =
            snap.hasData && snap.data!.exists ? AppUser.fromFirestore(snap.data!) : null;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.glassL2Bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.surface,
                backgroundImage: (user?.avatar.isNotEmpty ?? false)
                    ? CachedNetworkImageProvider(user!.avatar)
                    : null,
                child: (user?.avatar.isEmpty ?? true)
                    ? Icon(Icons.person, color: colors.textTertiary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user?.name ?? l10n.applicationList_loadingName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusTag(status: widget.app.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user == null
                          ? ''
                          : '${l10n.applicationList_userAge('${user.age ?? '—'}')} · ⭐ ${user.rating.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.app.status == ApplicationStatus.pending) ...[
                IconButton(
                  icon: const Icon(Icons.close),
                  color: colors.textSecondary,
                  onPressed: _busy ? null : _reject,
                  tooltip: l10n.applicationList_rejectTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle),
                  color: colors.primary,
                  onPressed: _busy ? null : _accept,
                  tooltip: l10n.applicationList_acceptTooltip,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final ApplicationStatus status;

  String _statusLabel(AppLocalizations l10n) => switch (status) {
    ApplicationStatus.pending => l10n.applicationList_statusPending,
    ApplicationStatus.accepted => l10n.applicationList_statusAccepted,
    ApplicationStatus.rejected => l10n.applicationList_statusRejected,
    ApplicationStatus.waitlisted => l10n.applicationList_statusWaitlisted,
    ApplicationStatus.expired => l10n.applicationList_statusExpired,
    ApplicationStatus.cancelled => l10n.applicationList_statusCancelled,
  };

  @override
  Widget build(BuildContext context) {
    final colors = GlassTheme.of(context).colors;
    final l10n = AppLocalizations.of(context)!;
    final tagColors = switch (status) {
      ApplicationStatus.accepted => (
          colors.primary.withValues(alpha: 0.1),
          colors.primary,
        ),
      ApplicationStatus.pending => (
          Colors.amber.withValues(alpha: 0.15),
          Colors.orange.shade700,
        ),
      ApplicationStatus.waitlisted => (
          Colors.blue.withValues(alpha: 0.1),
          Colors.blue.shade700,
        ),
      _ => (
          colors.surface,
          colors.textTertiary,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: tagColors.$1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusLabel(l10n),
        style: TextStyle(
          fontSize: 10,
          color: tagColors.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> showApplicationListSheet(BuildContext context, String postId) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: GlassTheme.of(context).colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => ApplicationListSheet(postId: postId),
  );
}
