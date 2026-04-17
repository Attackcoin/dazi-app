import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dazi_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../data/repositories/match_repository.dart';

/// 底部导航壳 —— 4 个 Tab：滑一滑 / 发现 / 消息 / 我的 + 发布按钮。
///
/// 使用 [StatefulNavigationShell] 实现 Tab 状态保持：
/// 切换 Tab 不会丢失滚动位置和页面状态。
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    final gt = GlassTheme.of(context);
    final unreadCount = ref.watch(unreadMatchCountProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/post/create'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: DaziColors.heroGradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gt.colors.primaryGlow,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: gt.colors.elevated.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: gt.colors.glassL1Border,
                  width: 0.5,
                ),
              ),
            ),
            child: BottomAppBar(
              color: Colors.transparent,
              elevation: 0,
              shape: const CircularNotchedRectangle(),
              notchMargin: Spacing.space8,
              height: 64,
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.swipe_outlined,
                    activeIcon: Icons.swipe,
                    label: l10n.home_tabSwipe,
                    selected: index == 0,
                    onTap: () => navigationShell.goBranch(0),
                  ),
                  _NavItem(
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                    label: l10n.home_tabDiscover,
                    selected: index == 1,
                    onTap: () => navigationShell.goBranch(1),
                  ),
                  const SizedBox(width: 48), // 给浮动按钮留位置
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: l10n.home_tabMessages,
                    selected: index == 2,
                    onTap: () => navigationShell.goBranch(2),
                    badgeCount: unreadCount,
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: l10n.home_tabProfile,
                    selected: index == 3,
                    onTap: () => navigationShell.goBranch(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final color = selected ? gt.colors.primary : gt.colors.textTertiary;

    Widget iconWidget;
    if (selected) {
      iconWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: gt.colors.primaryGlow,
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(activeIcon, color: gt.colors.primary, size: 24),
      );
    } else {
      iconWidget = Icon(icon, color: gt.colors.textTertiary, size: 24);
    }

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                iconWidget,
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: gt.colors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
