import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/models/circle.dart';
import '../../../data/repositories/circle_repository.dart';

/// 圈子详情页 —— 展示圈子信息 + 成员 + 动态列表。
class CircleDetailScreen extends ConsumerStatefulWidget {
  const CircleDetailScreen({super.key, required this.circleId});
  final String circleId;

  @override
  ConsumerState<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends ConsumerState<CircleDetailScreen> {
  final _momentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _momentCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinOrLeave(CircleMember? membership) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(circleRepositoryProvider);

    try {
      if (membership == null) {
        await repo.joinCircle(widget.circleId);
      } else {
        // 确认退出
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.circle_leave),
            content: Text(l10n.circle_leaveConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.common_cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.common_confirm),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await repo.leaveCircle(widget.circleId);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = membership == null
          ? l10n.circle_joinFailed(e.toString())
          : l10n.circle_leaveFailed(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _postMoment() async {
    final text = _momentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _posting = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(circleRepositoryProvider).postMoment(
            circleId: widget.circleId,
            text: text,
          );
      if (!mounted) return;
      _momentCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.circle_momentSent)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.circle_momentFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final circleAsync = ref.watch(circleProvider(widget.circleId));
    final membershipAsync =
        ref.watch(myCircleMembershipProvider(widget.circleId));
    final momentsAsync = ref.watch(circleMomentsProvider(widget.circleId));
    final membership = membershipAsync.valueOrNull;
    final isMember = membership != null;

    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: circleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(l10n.common_loadFailed,
                style: TextStyle(color: gt.colors.textSecondary)),
          ),
          data: (circle) {
            if (circle == null) {
              return Center(
                child: Text(l10n.common_loadFailed,
                    style: TextStyle(color: gt.colors.textSecondary)),
              );
            }
            return CustomScrollView(
              slivers: [
                // Header
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  title: Text(circle.name),
                  pinned: true,
                  actions: [
                    if (isMember && membership.role != CircleRole.owner)
                      IconButton(
                        icon: const Icon(Icons.exit_to_app),
                        tooltip: l10n.circle_leave,
                        onPressed: () => _joinOrLeave(membership),
                      ),
                  ],
                ),
                // 圈子信息卡
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.space16,
                      vertical: Spacing.space8,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(Spacing.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color:
                                      gt.colors.primary.withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(Radii.pill),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  circle.icon.isNotEmpty
                                      ? circle.icon
                                      : circle.name.characters.first,
                                  style: TextStyle(
                                    fontSize: circle.icon.isNotEmpty ? 28 : 24,
                                    fontWeight: FontWeight.w600,
                                    color: gt.colors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Spacing.space12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      circle.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: gt.colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: Spacing.space4),
                                    Row(
                                      children: [
                                        PillTag(
                                            label: l10n.circle_memberCount(
                                                circle.memberCount)),
                                        const SizedBox(width: Spacing.space8),
                                        PillTag(
                                            label: l10n.circle_postCount(
                                                circle.postCount)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (circle.description.isNotEmpty) ...[
                            const SizedBox(height: Spacing.space12),
                            Text(
                              circle.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: gt.colors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: Spacing.space12),
                          // 加入/已加入 按钮
                          if (!isMember)
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () => _joinOrLeave(null),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: gt.colors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(Radii.button),
                                  ),
                                ),
                                child: Text(l10n.circle_join),
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check, size: 18),
                                label: Text(l10n.circle_joined),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: gt.colors.primary,
                                  side: BorderSide(color: gt.colors.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(Radii.button),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 发动态输入框（仅成员可见���
                if (isMember)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.space16,
                        vertical: Spacing.space4,
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.all(Spacing.space12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _momentCtrl,
                                maxLines: 2,
                                minLines: 1,
                                style:
                                    TextStyle(color: gt.colors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: l10n.circle_momentHint,
                                  hintStyle: TextStyle(
                                      color: gt.colors.textTertiary),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(width: Spacing.space8),
                            IconButton(
                              onPressed: _posting ? null : _postMoment,
                              icon: _posting
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: gt.colors.primary,
                                      ),
                                    )
                                  : Icon(Icons.send,
                                      color: gt.colors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // 动态列表标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.space16,
                      Spacing.space16,
                      Spacing.space16,
                      Spacing.space8,
                    ),
                    child: Text(
                      l10n.circle_moments,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                // 动态列表
                momentsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(Spacing.space32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(
                      child: Text(l10n.common_loadFailed,
                          style: TextStyle(color: gt.colors.textSecondary)),
                    ),
                  ),
                  data: (moments) {
                    if (moments.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(Spacing.space32),
                          child: Center(
                            child: Text(
                              l10n.circle_emptyMoments,
                              style: TextStyle(
                                  color: gt.colors.textTertiary),
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.space16),
                      sliver: SliverList.separated(
                        itemCount: moments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: Spacing.space12),
                        itemBuilder: (_, index) =>
                            _MomentCard(moment: moments[index]),
                      ),
                    );
                  },
                ),
                // 底部留白
                const SliverToBoxAdapter(
                  child: SizedBox(height: Spacing.space32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});
  final CircleMoment moment;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(Spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者行
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: gt.colors.primary.withValues(alpha: 0.15),
                backgroundImage: moment.authorAvatar.isNotEmpty
                    ? NetworkImage(moment.authorAvatar)
                    : null,
                child: moment.authorAvatar.isEmpty
                    ? Text(
                        moment.authorName.isNotEmpty
                            ? moment.authorName.characters.first
                            : '?',
                        style: TextStyle(
                          fontSize: 14,
                          color: gt.colors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: Spacing.space8),
              Expanded(
                child: Text(
                  moment.authorName.isNotEmpty ? moment.authorName : '...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textPrimary,
                  ),
                ),
              ),
              if (moment.createdAt != null)
                Text(
                  _formatTime(moment.createdAt!),
                  style: TextStyle(
                    fontSize: 12,
                    color: gt.colors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.space8),
          // 内容
          Text(
            moment.text,
            style: TextStyle(
              fontSize: 15,
              color: gt.colors.textPrimary,
              height: 1.5,
            ),
          ),
          // 图片（网格）
          if (moment.images.isNotEmpty) ...[
            const SizedBox(height: Spacing.space8),
            Wrap(
              spacing: Spacing.space4,
              runSpacing: Spacing.space4,
              children: moment.images.map((url) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(Spacing.space8),
                  child: Image.network(
                    url,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: gt.colors.glassL2Bg,
                      child: Icon(Icons.image,
                          color: gt.colors.textTertiary),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
