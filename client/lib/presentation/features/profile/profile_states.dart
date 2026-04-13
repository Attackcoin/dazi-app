part of 'profile_screen.dart';

// ============================================================
// 状态（空/错误/骨架）+ TabBar 粘性 delegate
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
