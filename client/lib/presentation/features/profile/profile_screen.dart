import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/app_user.dart';
import '../../../data/models/application.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/application_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/user_repository.dart';

part 'profile_tabs.dart';

/// 个人主页。
///
/// - 不传 [uid] → 展示当前登录用户自己（底部导航 `/profile` 入口使用）
/// - 传 [uid] → 展示该 uid 的主页，若等于当前 auth uid 仍是自己视角
///
/// 未登录（且未传 [uid]）→ 引导登录态。
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.uid});

  /// 目标用户 uid。null 表示当前登录用户。
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final authUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final targetUid = uid ?? authUid;

    // 未登录且未显式传 uid —— 引导登录。
    if (targetUid == null) {
      return GlowBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_circle_outlined,
                    size: 80, color: gt.colors.textTertiary),
                const SizedBox(height: 12),
                Text('尚未登录',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.textSecondary)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(
                      backgroundColor: gt.colors.primary),
                  child: const Text('去登录'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final userAsync = ref.watch(userByIdProvider(targetUid));
    final isSelf = authUid != null && authUid == targetUid;

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: userAsync.when(
          loading: () => const _ProfileSkeleton(),
          error: (e, _) => _ErrorState(
            message: '加载失败：$e',
            onRetry: () => ref.invalidate(userByIdProvider(targetUid)),
          ),
          data: (user) {
            if (user == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('用户不存在或已注销',
                      style: TextStyle(color: gt.colors.textSecondary)),
                ),
              );
            }
            return _ProfileView(user: user, isSelf: isSelf);
          },
        ),
      ),
    );
  }
}

// ============================================================
// 主视图
// ============================================================

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({required this.user, required this.isSelf});

  final AppUser user;
  final bool isSelf;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final user = widget.user;

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: gt.colors.primary,
            actions: [
              if (widget.isSelf) ...[
                IconButton(
                  tooltip: '编辑资料',
                  icon: Semantics(
                    label: '编辑资料',
                    button: true,
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white),
                  ),
                  onPressed: () => context.push('/settings/edit'),
                ),
                IconButton(
                  tooltip: '设置',
                  icon: Semantics(
                    label: '设置',
                    button: true,
                    child: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                  ),
                  onPressed: () => _showSettingsSheet(context, ref),
                ),
              ] else
                PopupMenuButton<String>(
                  icon: Semantics(
                    label: '更多操作',
                    button: true,
                    child: const Icon(Icons.more_horiz, color: Colors.white),
                  ),
                  onSelected: (v) => _onOtherMenu(context, ref, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'report', child: Text('举报')),
                    PopupMenuItem(value: 'block', child: Text('拉黑')),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeaderBackground(user: user),
            ),
          ),
          SliverToBoxAdapter(
            child: GlassCard(
              level: 1,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _MetaSection(user: user),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tab,
                labelColor: gt.colors.primary,
                unselectedLabelColor: gt.colors.textSecondary,
                indicatorColor: gt.colors.primary,
                indicatorWeight: 2.5,
                tabs: [
                  Tab(text: widget.isSelf ? '我发布的' : 'TA 发布的'),
                  Tab(text: widget.isSelf ? '我申请的' : 'TA 申请的'),
                  const Tab(text: '参加过'),
                ],
              ),
            ),
          ),
        ],
      body: TabBarView(
        controller: _tab,
        children: [
          _MyPostsTab(uid: user.id),
          _MyApplicationsTab(uid: user.id),
          _JoinedTab(user: user),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: gt.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: gt.colors.glassL1Border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _settingTile(sheetCtx, Icons.phone_outlined, '紧急联系人',
                '/settings/emergency'),
            _settingTile(sheetCtx, Icons.notifications_outlined, '通知设置',
                '/settings/notifications'),
            _settingTile(sheetCtx, Icons.lock_outline, '隐私设置',
                '/settings/privacy'),
            _settingTile(sheetCtx, Icons.block, '黑名单',
                '/settings/blocked'),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: gt.colors.error),
              title: Text('退出登录',
                  style: TextStyle(color: gt.colors.error)),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await ref.read(authRepositoryProvider).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(
      BuildContext ctx, IconData icon, String label, String route) {
    final gt = GlassTheme.of(ctx);
    return ListTile(
      leading: Icon(icon, color: gt.colors.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Icon(Icons.chevron_right, color: gt.colors.textTertiary),
      onTap: () {
        Navigator.of(ctx).pop();
        ctx.push(route);
      },
    );
  }

  Future<void> _onOtherMenu(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'report') {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('选择举报原因'),
          children: [
            for (final r in ['虚假信息', '骚扰行为', '色情低俗', '欺诈诈骗', '其他'])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, r),
                child: Text(r),
              ),
          ],
        ),
      );
      if (reason == null || !context.mounted) return;
      try {
        await ref.read(userRepositoryProvider).report(
              targetId: widget.user.id,
              targetType: 'user',
              reason: reason,
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已记录举报，我们会尽快处理')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('举报失败：$e')),
        );
      }
      return;
    }
    if (action == 'block') {
      try {
        await ref.read(userRepositoryProvider).blockUser(widget.user.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已拉黑')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')),
        );
      }
    }
  }
}

// ============================================================
// 头部渐变 + 头像 + 昵称 + 评分 + 信用徽章
// ============================================================

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A65), Color(0xFFFF6B9D), Color(0xFFA855F7)],
      )),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'avatar-${user.id}',
                child: _Avatar(url: user.avatar, size: 80),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '昵称 ${user.name}',
                header: true,
                child: Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star, color: gt.colors.starColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    user.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '· ',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${user.reviewCount} 条评价',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  if (user.sesameAuthorized) const _SesameBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SesameBadge extends StatelessWidget {
  const _SesameBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '信用徽章：芝麻信用已授权',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white54),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, color: Colors.white, size: 13),
            SizedBox(width: 3),
            Text('信用',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '用户头像',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.white24,
        ),
        child: ClipOval(
          child: url.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 40)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.white24,
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.person, color: Colors.white, size: 40),
                ),
        ),
      ),
    );
  }
}

// ============================================================
// 性别 / 年龄 / 城市 / bio / 标签 / 统计
// ============================================================

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 性别 / 年龄 / 城市 chip 行
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: _genderIcon(user.gender),
                label: _genderLabel(user.gender),
                color: _genderColor(gt, user.gender),
              ),
              if (user.age != null)
                _InfoChip(
                  icon: Icons.cake_outlined,
                  label: '${user.age} 岁',
                  color: gt.colors.textSecondary,
                ),
              if (user.city.isNotEmpty)
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: user.city,
                  color: gt.colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // bio
          if (user.bio.trim().isEmpty)
            Text(
              '这位搭子还没有写简介',
              style: TextStyle(color: gt.colors.textTertiary, fontSize: 13),
            )
          else
            Semantics(
              label: '个人简介',
              child: Text(
                user.bio,
                style: TextStyle(
                  color: gt.colors.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          const SizedBox(height: 20),
          _StatsRow(user: user),
          const SizedBox(height: 20),
          _SectionTitle('兴趣标签'),
          const SizedBox(height: 10),
          if (user.tags.isEmpty)
            Text('还没有设置兴趣标签',
                style: TextStyle(color: gt.colors.textTertiary, fontSize: 13))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: gt.colors.glassL1Bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: gt.colors.glassL1Border),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                color: gt.colors.textPrimary)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static IconData _genderIcon(String g) => switch (g) {
        'male' => Icons.male,
        'female' => Icons.female,
        _ => Icons.transgender,
      };
  static String _genderLabel(String g) => switch (g) {
        'male' => '男',
        'female' => '女',
        _ => '其他',
      };
  static Color _genderColor(GlassThemeData gt, String g) => switch (g) {
        'male' => gt.colors.male,
        'female' => gt.colors.female,
        _ => gt.colors.textSecondary,
      };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: gt.colors.glassL1Bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gt.colors.glassL1Border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: gt.colors.glassL1Bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gt.colors.glassL1Border),
      ),
      child: Row(
        children: [
          _item(gt, '${user.totalMeetups}', '已完成'),
          _divider(gt),
          _item(gt, '${user.ghostCount}', '爽约'),
          _divider(gt),
          _item(gt, '${user.badges.length}', '勋章'),
        ],
      ),
    );
  }

  Widget _item(GlassThemeData gt, String value, String label) => Expanded(
        child: Semantics(
          label: '$label $value',
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: gt.colors.textPrimary)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: gt.colors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _divider(GlassThemeData gt) => Container(
        width: 1,
        height: 28,
        color: gt.colors.glassL1Border,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: gt.colors.textPrimary,
      ),
    );
  }
}


// ============================================================
// 状态（空/错误/骨架）
// ============================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined,
              size: 56, color: gt.colors.textTertiary),
          const SizedBox(height: 10),
          Text(text,
              style: TextStyle(
                  color: gt.colors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: gt.colors.textTertiary),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: gt.colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8A65), Color(0xFFFF6B9D), Color(0xFFA855F7)],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBar(gt, width: 120, height: 14),
                const SizedBox(height: 10),
                _skeletonBar(gt, width: double.infinity, height: 12),
                const SizedBox(height: 6),
                _skeletonBar(gt, width: 220, height: 12),
                const SizedBox(height: 18),
                _skeletonBar(gt, width: double.infinity, height: 64),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _skeletonBar(GlassThemeData gt,
          {required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: gt.colors.glassL1Bg,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}

// ============================================================
// TabBar 粘性 delegate
// ============================================================

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final gt = GlassTheme.of(context);
    return Container(
      color: gt.colors.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => old.tabBar != tabBar;
}
