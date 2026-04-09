import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '申请列表',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: appsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败：$e')),
                data: (apps) {
                  if (apps.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          '还没有人申请哦～',
                          style: TextStyle(
                            color: AppColors.textTertiary,
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
        const SnackBar(content: Text('已接受申请 ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
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
        const SnackBar(content: Text('已拒绝')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreProvider);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestore.collection('users').doc(widget.app.applicantId).get(),
      builder: (context, snap) {
        final user =
            snap.hasData && snap.data!.exists ? AppUser.fromFirestore(snap.data!) : null;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.surface,
                backgroundImage: (user?.avatar.isNotEmpty ?? false)
                    ? CachedNetworkImageProvider(user!.avatar)
                    : null,
                child: (user?.avatar.isEmpty ?? true)
                    ? const Icon(Icons.person, color: AppColors.textTertiary)
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
                          user?.name ?? '加载中...',
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
                          : '${user.age ?? '—'}岁 · ⭐ ${user.rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.app.status == ApplicationStatus.pending) ...[
                IconButton(
                  icon: const Icon(Icons.close),
                  color: AppColors.textSecondary,
                  onPressed: _busy ? null : _reject,
                  tooltip: '拒绝',
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle),
                  color: AppColors.primary,
                  onPressed: _busy ? null : _accept,
                  tooltip: '接受',
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

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      ApplicationStatus.accepted => (
          AppColors.primary.withValues(alpha: 0.1),
          AppColors.primary,
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
          AppColors.surface,
          AppColors.textTertiary,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          color: colors.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Future<void> showApplicationListSheet(BuildContext context, String postId) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => ApplicationListSheet(postId: postId),
  );
}
