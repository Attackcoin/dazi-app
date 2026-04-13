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

part 'profile_header.dart';
part 'profile_meta.dart';
part 'profile_states.dart';
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

// 头部 / 元信息 / 状态 / TabBar delegate 等 private widget 见 part 文件:
//   profile_header.dart / profile_meta.dart / profile_states.dart / profile_tabs.dart
