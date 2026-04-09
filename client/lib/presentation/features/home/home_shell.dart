import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// 底部导航壳 —— 包裹广场/消息/我的等主页面。
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});

  final Widget child;

  int _indexOf(String path) {
    if (path.startsWith('/profile')) return 2;
    if (path.startsWith('/messages')) return 1;
    return 0;
  }


  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).matchedLocation;
    final index = _indexOf(path);

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/post/create'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.bolt, color: Colors.white),
        label: const Text(
          '即刻出发',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
              label: '广场',
              selected: index == 0,
              onTap: () => context.go('/'),
            ),
            _NavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: '消息',
              selected: index == 1,
              onTap: () => context.go('/messages'),
            ),
            const SizedBox(width: 48), // 给浮动按钮留位置
            _NavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: '我的',
              selected: index == 2,
              onTap: () => context.go('/profile'),
            ),
          ],
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
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
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
