import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/celebration_overlay.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/application_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/post_repository.dart';

// ============================================================
// 常量
// ============================================================

const _swipeThreshold = 100.0;
const _rotationFactor = 0.0008;
const _backCardScale = 0.92;
const _backCardOpacity = 0.6;

// ============================================================
// SwipeScreen
// ============================================================

/// Tinder 风格滑动首页 —— 左滑跳过，右滑加入。
class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _joining = false;

  late final AnimationController _flyController;
  late final AnimationController _springController;
  late final AnimationController _successController;

  Animation<Offset>? _flyAnimation;
  Animation<Offset>? _springAnimation;

  // 跳过的 post id 集合（不持久化，刷新后重置）
  final Set<String> _skippedIds = {};

  @override
  void initState() {
    super.initState();
    // 必须在 initState 里立刻构造（而非 late final 懒加载）。
    // 若懒加载，widget 在首次 pump 后立即被 deactivate（例如 tearDown 触发登出
    // 重建路由树），dispose() 才第一次访问 controller → 此时 createTicker
    // 调 getInheritedWidgetOfExactType 查已 deactivate 的 ancestor → 抛异常。
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _flyController.dispose();
    _springController.dispose();
    _successController.dispose();
    super.dispose();
  }

  // ============================================================
  // 手势处理
  // ============================================================

  void _onPanUpdate(DragUpdateDetails d) {
    if (_joining || _flyController.isAnimating) return;
    setState(() => _dragOffset += d.delta);

    // 触觉反馈：跨过阈值时震一下
    if ((_dragOffset.dx.abs() - _swipeThreshold).abs() < 5) {
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details, Post post) {
    if (_joining || _flyController.isAnimating) return;

    final velocity = details.velocity.pixelsPerSecond.dx;
    // 快速甩动 or 超过阈值
    if (_dragOffset.dx > _swipeThreshold || velocity > 800) {
      _handleJoin(post);
    } else if (_dragOffset.dx < -_swipeThreshold || velocity < -800) {
      _handleSkip(post);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _springAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _springController,
      curve: Curves.elasticOut,
    ));
    _springController.forward(from: 0).then((_) {
      if (!mounted) return;
      _springAnimation = null;
      setState(() => _dragOffset = Offset.zero);
    });
  }

  void _flyAway(Offset target, {required VoidCallback onDone}) {
    _flyAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeInCubic,
    ));
    _flyController.forward(from: 0).then((_) {
      _flyAnimation = null;
      onDone();
    });
  }

  void _handleSkip(Post post) {
    HapticFeedback.lightImpact();
    final sw = MediaQuery.of(context).size.width;
    _flyAway(Offset(-sw * 1.5, _dragOffset.dy), onDone: () {
      _skippedIds.add(post.id);
      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
      });
    });
  }

  Future<void> _handleJoin(Post post) async {
    if (_joining) return;
    HapticFeedback.mediumImpact();
    setState(() => _joining = true);

    final sw = MediaQuery.of(context).size.width;
    _flyAway(Offset(sw * 1.5, _dragOffset.dy), onDone: () async {
      try {
        await ref
            .read(applicationRepositoryProvider)
            .applyToPost(post.id);

        if (!mounted) return;

        setState(() {
          _currentIndex++;
          _dragOffset = Offset.zero;
          _joining = false;
        });

        // 使用 CelebrationOverlay 替代自定义 overlay
        await CelebrationOverlay.showJoinSuccess(context, title: post.title);
        if (!mounted) return;

        // 跳到群聊（用 postId 作为 chatId）
        context.push('/chat/${post.id}');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失败：$e')),
        );
        setState(() {
          _currentIndex++;
          _dragOffset = Offset.zero;
          _joining = false;
        });
      }
    });
  }

  // ============================================================
  // 构建列表
  // ============================================================

  List<Post> _filterPosts(List<Post> posts) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    return posts
        .where((p) => p.userId != uid && !_skippedIds.contains(p.id))
        .toList();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final city = appUser?.city.isNotEmpty == true ? appUser!.city : null;
    final query = FeedQuery(city: city);
    final feedAsync = ref.watch(feedProvider(query));

    return Scaffold(
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Icon(Icons.location_on, color: gt.colors.primary, size: 18),
            const SizedBox(width: 4),
            Text(
              city ?? '附近',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: GlowBackground(
        child: feedAsync.when(
          data: (posts) {
            final available = _filterPosts(posts);
            if (_currentIndex >= available.length) {
              return const _EmptyState();
            }
            return _buildCardStack(available, gt);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48,
                    color: gt.colors.textTertiary),
                const SizedBox(height: 12),
                const Text('加载失败'),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(feedProvider(query)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStack(List<Post> available, GlassThemeData gt) {
    return Stack(
      children: [
        // 背景卡片
        if (_currentIndex + 1 < available.length)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 100),
              child: AnimatedBuilder(
                animation: _flyController,
                builder: (_, child) {
                  // 拖动时背景卡片逐渐放大到位
                  final progress =
                      (_dragOffset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);
                  final scale =
                      _backCardScale + (1 - _backCardScale) * progress;
                  final opacity =
                      _backCardOpacity + (1 - _backCardOpacity) * progress;
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  );
                },
                child: _SwipeCard(post: available[_currentIndex + 1]),
              ),
            ),
          ),

        // 当前卡片
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            child: AnimatedBuilder(
              animation: Listenable.merge([_flyController, _springController]),
              builder: (_, child) {
                final offset = _flyAnimation?.value ??
                    _springAnimation?.value ??
                    _dragOffset;
                final angle = offset.dx * _rotationFactor;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(offset.dx, offset.dy)
                    ..rotateZ(angle),
                  child: child,
                );
              },
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: (d) => _onPanEnd(d, available[_currentIndex]),
                child: Stack(
                  children: [
                    _SwipeCard(post: available[_currentIndex]),
                    // 左滑标签
                    _SwipeLabel(
                      alignment: Alignment.topRight,
                      rotation: 0.3,
                      text: '跳过',
                      color: gt.colors.error,
                      opacity: ((-_dragOffset.dx - 30) / 70).clamp(0, 1),
                    ),
                    // 右滑标签
                    _SwipeLabel(
                      alignment: Alignment.topLeft,
                      rotation: -0.3,
                      text: '加入',
                      color: gt.colors.success,
                      opacity: ((_dragOffset.dx - 30) / 70).clamp(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 底部操作按钮
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.close,
                color: gt.colors.error,
                size: 56,
                onTap: _joining
                    ? null
                    : () => _handleSkip(available[_currentIndex]),
              ),
              const SizedBox(width: 40),
              _ActionButton(
                icon: Icons.bolt,
                color: gt.colors.success,
                size: 64,
                onTap: _joining
                    ? null
                    : () => _handleJoin(available[_currentIndex]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 滑动标签（跳过 / 加入）
// ============================================================

class _SwipeLabel extends StatelessWidget {
  const _SwipeLabel({
    required this.alignment,
    required this.rotation,
    required this.text,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final double rotation;
  final String text;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Positioned(
      top: 40,
      left: alignment == Alignment.topLeft ? 30 : null,
      right: alignment == Alignment.topRight ? 30 : null,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: rotation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 滑动卡片（GlassCard level:1 + accent glow border shadow）
// ============================================================

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final tags = <String>[
      post.costType.label,
      if (post.isSocialAnxietyFriendly) '社恐友好',
    ];

    return GlassCard(
      level: 1,
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gt.colors.accentGlow,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部图片
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildHeroImage(gt),
                    // 底部渐变
                    Positioned(
                      left: 0, right: 0, bottom: 0, height: 140,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 分类 + 标题
                    Positioned(
                      left: 20, right: 20, bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: gt.colors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              post.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 下半部分信息
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow(Icons.schedule,
                          post.time != null
                              ? DateFormat('M月d日 EEE HH:mm', 'zh_CN')
                                  .format(post.time!)
                              : '时间待定',
                          gt),
                      const SizedBox(height: 10),
                      _infoRow(Icons.location_on_outlined,
                          post.location?.name ?? '地点待定', gt),
                      const SizedBox(height: 10),
                      _infoRow(Icons.people_outline,
                          '${post.acceptedCount}/${post.totalSlots} 人', gt),
                      const Spacer(),
                      // 标签
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tags.map((t) => _tag(t, gt)).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage(GlassThemeData gt) {
    if (post.images.isNotEmpty) {
      return Image.network(
        post.images.first,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultHero(gt),
      );
    }
    return _defaultHero(gt);
  }

  Widget _defaultHero(GlassThemeData gt) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gt.colors.accent, gt.colors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _categoryIcon(post.category),
          size: 80,
          color: Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  static IconData _categoryIcon(String cat) {
    if (cat.contains('吃') || cat.contains('喝') || cat.contains('火锅')) {
      return Icons.restaurant;
    }
    if (cat.contains('运动') || cat.contains('健身')) return Icons.fitness_center;
    if (cat.contains('游戏') || cat.contains('娱乐')) return Icons.sports_esports;
    if (cat.contains('旅') || cat.contains('出行')) return Icons.flight;
    if (cat.contains('学') || cat.contains('读书')) return Icons.menu_book;
    return Icons.celebration;
  }

  Widget _infoRow(IconData icon, String text, GlassThemeData gt) {
    return Row(
      children: [
        Icon(icon, size: 18, color: gt.colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: gt.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tag(String label, GlassThemeData gt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: gt.colors.glassL2Bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gt.colors.glassL2Border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: gt.colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ============================================================
// 操作按钮
// ============================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: gt.colors.glassL1Bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color, width: 2.5),
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

// ============================================================
// 空状态
// ============================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👀', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              '附近的局都看完了',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '下拉刷新或自己发一个局吧!',
              style: TextStyle(color: gt.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
