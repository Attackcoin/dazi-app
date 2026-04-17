import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locale/locale_provider.dart';
import '../../../core/theme/dazi_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
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
      final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.profile_notLoggedIn,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.textSecondary)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(
                      backgroundColor: gt.colors.primary),
                  child: Text(l10n.profile_goLogin),
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
          error: (e, _) {
            final l10n = AppLocalizations.of(context)!;
            return _ErrorState(
              message: l10n.common_loadFailedWithError('$e'),
              onRetry: () => ref.invalidate(userByIdProvider(targetUid)),
            );
          },
          data: (user) {
            if (user == null) {
              final l10n = AppLocalizations.of(context)!;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.profile_userNotExist,
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
    final l10n = AppLocalizations.of(context)!;
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
                  tooltip: l10n.profile_editProfile,
                  icon: Semantics(
                    label: l10n.profile_editProfile,
                    button: true,
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white),
                  ),
                  onPressed: () => context.push('/settings/edit'),
                ),
                IconButton(
                  tooltip: l10n.profile_settings,
                  icon: Semantics(
                    label: l10n.profile_settings,
                    button: true,
                    child: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                  ),
                  onPressed: () => _showSettingsSheet(context, ref),
                ),
              ] else
                PopupMenuButton<String>(
                  icon: Semantics(
                    label: l10n.profile_moreActions,
                    button: true,
                    child: const Icon(Icons.more_horiz, color: Colors.white),
                  ),
                  onSelected: (v) => _onOtherMenu(context, ref, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'report', child: Text(l10n.profile_report)),
                    PopupMenuItem(value: 'block', child: Text(l10n.profile_block)),
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
          if (widget.isSelf && user.verificationLevel < 2)
            SliverToBoxAdapter(
              child: _VerifyIdentityPrompt(
                onTap: () => _showVerifySheet(context),
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
                  Tab(text: widget.isSelf ? l10n.profile_tabMyPosts_self : l10n.profile_tabMyPosts_other),
                  Tab(text: widget.isSelf ? l10n.profile_tabMyApplications_self : l10n.profile_tabMyApplications_other),
                  Tab(text: l10n.profile_tabJoined),
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
    final l10n = AppLocalizations.of(context)!;
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
            _settingTile(sheetCtx, Icons.phone_outlined, l10n.profile_emergencyContacts,
                '/settings/emergency'),
            _settingTile(sheetCtx, Icons.notifications_outlined, l10n.profile_notificationSettings,
                '/settings/notifications'),
            _settingTile(sheetCtx, Icons.lock_outline, l10n.profile_privacySettings,
                '/settings/privacy'),
            _settingTile(sheetCtx, Icons.password, l10n.profile_setLoginPassword,
                '/settings/password'),
            _settingTile(sheetCtx, Icons.block, l10n.profile_blacklist,
                '/settings/blocked'),
            _languageTile(sheetCtx, ref, l10n),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: gt.colors.error),
              title: Text(l10n.profile_logout,
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

  Widget _languageTile(BuildContext ctx, WidgetRef ref, AppLocalizations l10n) {
    final gt = GlassTheme.of(ctx);
    final current = ref.watch(localeProvider);
    final label = current == null
        ? l10n.locale_system
        : _localeName(l10n, current.languageCode);
    return ListTile(
      leading: Icon(Icons.language, color: gt.colors.textSecondary),
      title: Text(l10n.profile_language, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: gt.colors.textTertiary)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: gt.colors.textTertiary),
        ],
      ),
      onTap: () {
        Navigator.of(ctx).pop();
        _showLanguagePicker(context, ref);
      },
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(localeProvider);
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
            _langOption(sheetCtx, ref, l10n.locale_system, null, current == null, gt),
            _langOption(sheetCtx, ref, l10n.locale_zh, const Locale('zh'), current?.languageCode == 'zh', gt),
            _langOption(sheetCtx, ref, l10n.locale_en, const Locale('en'), current?.languageCode == 'en', gt),
            _langOption(sheetCtx, ref, l10n.locale_ja, const Locale('ja'), current?.languageCode == 'ja', gt),
            _langOption(sheetCtx, ref, l10n.locale_ko, const Locale('ko'), current?.languageCode == 'ko', gt),
            _langOption(sheetCtx, ref, l10n.locale_es, const Locale('es'), current?.languageCode == 'es', gt),
            _langOption(sheetCtx, ref, l10n.locale_fr, const Locale('fr'), current?.languageCode == 'fr', gt),
            _langOption(sheetCtx, ref, l10n.locale_de, const Locale('de'), current?.languageCode == 'de', gt),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _langOption(BuildContext ctx, WidgetRef ref, String label,
      Locale? locale, bool selected, GlassThemeData gt) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: selected
          ? Icon(Icons.check, color: gt.colors.primary)
          : null,
      onTap: () {
        ref.read(localeProvider.notifier).state = locale;
        LocalePersistence.save(locale);
        Navigator.of(ctx).pop();
      },
    );
  }

  String _localeName(AppLocalizations l10n, String code) {
    return switch (code) {
      'zh' => l10n.locale_zh,
      'en' => l10n.locale_en,
      'ja' => l10n.locale_ja,
      'ko' => l10n.locale_ko,
      'es' => l10n.locale_es,
      'fr' => l10n.locale_fr,
      'de' => l10n.locale_de,
      _ => code,
    };
  }

  void _showVerifySheet(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: gt.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: gt.colors.glassL1Border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.verified_user,
                  size: 48, color: gt.colors.info),
              const SizedBox(height: 16),
              Text(
                l10n.profile_verifyIdentity,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: gt.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.profile_verifyBenefits,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: gt.colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.profile_verifyComingSoon)),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: gt.colors.info,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.profile_verifyStart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onOtherMenu(
      BuildContext context, WidgetRef ref, String action) async {
    final l10n = AppLocalizations.of(context)!;
    if (action == 'report') {
      final reasons = [
        l10n.profile_reportReason_fake,
        l10n.profile_reportReason_harassment,
        l10n.profile_reportReason_porn,
        l10n.profile_reportReason_fraud,
        l10n.profile_reportReason_other,
      ];
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(l10n.profile_reportTitle),
          children: [
            for (final r in reasons)
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
          SnackBar(content: Text(l10n.profile_reportRecorded)),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profile_reportFailed('$e'))),
        );
      }
      return;
    }
    if (action == 'block') {
      try {
        await ref.read(userRepositoryProvider).blockUser(widget.user.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profile_blocked)),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.common_actionFailed('$e'))),
        );
      }
    }
  }
}

/// 身份验证入口提示条 — 仅自己主页 + verificationLevel < 2 时显示。
class _VerifyIdentityPrompt extends StatelessWidget {
  const _VerifyIdentityPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 2,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.space16, vertical: Spacing.space12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: gt.colors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.verified_user,
                    size: 20, color: gt.colors.info),
              ),
              const SizedBox(width: Spacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profile_verifyIdentity,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.profile_verifyBenefits,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: gt.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.space8),
              Icon(Icons.chevron_right,
                  size: 20, color: gt.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

// 头部 / 元信息 / 状态 / TabBar delegate 等 private widget 见 part 文件:
//   profile_header.dart / profile_meta.dart / profile_states.dart / profile_tabs.dart
