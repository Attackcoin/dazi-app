import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/models/category_config.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/post_repository.dart';

/// 发现页 —— 列表形式展示所有局，支持筛选。
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _category = '';
  _TimeFilter _timeFilter = _TimeFilter.all;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final city = appUser?.city.isNotEmpty == true ? appUser!.city : null;
    final query = FeedQuery(
      city: city,
      category: _category.isEmpty ? null : _category,
    );
    final feedAsync = ref.watch(feedProvider(query));
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryConfig>[];

    return Scaffold(
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('发现'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: GlowBackground(
        child: Column(
          children: [
            // 筛选栏
            _FilterBar(
              categories: categories,
              selectedCategory: _category,
              timeFilter: _timeFilter,
              onCategoryChanged: (v) => setState(() => _category = v),
              onTimeChanged: (v) => setState(() => _timeFilter = v),
            ),
            // 列表
            Expanded(
              child: feedAsync.when(
                data: (posts) {
                  final filtered = _applyLocalFilters(posts);
                  if (filtered.isEmpty) {
                    return const _EmptyState();
                  }
                  return RefreshIndicator(
                    color: gt.colors.primary,
                    onRefresh: () async {
                      ref.invalidate(feedProvider(query));
                      await ref.read(feedProvider(query).future);
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => AnimatedListItem(
                        index: i,
                        child: _DiscoverCard(
                          post: filtered[i],
                          onTap: () => context.push('/post/${filtered[i].id}'),
                        ),
                      ),
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
          ],
        ),
      ),
    );
  }

  List<Post> _applyLocalFilters(List<Post> posts) {
    var result = posts;

    // 时间筛选
    final now = DateTime.now();
    switch (_timeFilter) {
      case _TimeFilter.today:
        result = result
            .where((p) =>
                p.time != null && DateUtils.isSameDay(p.time!, now))
            .toList();
        break;
      case _TimeFilter.thisWeek:
        final weekEnd = now.add(Duration(days: 7 - now.weekday));
        result = result
            .where(
                (p) => p.time != null && p.time!.isBefore(weekEnd))
            .toList();
        break;
      case _TimeFilter.thisMonth:
        result = result
            .where((p) =>
                p.time != null &&
                p.time!.month == now.month &&
                p.time!.year == now.year)
            .toList();
        break;
      case _TimeFilter.all:
        break;
    }

    return result;
  }
}

enum _TimeFilter { all, today, thisWeek, thisMonth }

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.timeFilter,
    required this.onCategoryChanged,
    required this.onTimeChanged,
  });

  final List<CategoryConfig> categories;
  final String selectedCategory;
  final _TimeFilter timeFilter;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<_TimeFilter> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: gt.colors.glassL1Border, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 分类筛选 — PillTag
            PillTag(
              label: selectedCategory.isEmpty ? '全部分类' : selectedCategory,
              selected: selectedCategory.isNotEmpty,
              onTap: () => _showCategorySheet(context),
            ),
            const SizedBox(width: 8),
            // 时间筛选 — PillTag
            PillTag(
              label: _timeLabel(timeFilter),
              selected: timeFilter != _TimeFilter.all,
              onTap: () => _showTimeSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(_TimeFilter f) {
    switch (f) {
      case _TimeFilter.all:
        return '时间';
      case _TimeFilter.today:
        return '今天';
      case _TimeFilter.thisWeek:
        return '本周';
      case _TimeFilter.thisMonth:
        return '本月';
    }
  }

  void _showCategorySheet(BuildContext context) {
    final gt = GlassTheme.of(context);
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: gt.colors.surface,
      builder: (ctx) => SafeArea(
        child: GlassCard(
          level: 2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('全部分类'),
                trailing: selectedCategory.isEmpty
                    ? Icon(Icons.check, color: gt.colors.primary)
                    : null,
                onTap: () {
                  onCategoryChanged('');
                  Navigator.pop(ctx);
                },
              ),
              ...categories.map((c) => ListTile(
                    leading: Text(c.emoji, style: const TextStyle(fontSize: 20)),
                    title: Text(c.label),
                    trailing: selectedCategory == c.id
                        ? Icon(Icons.check, color: gt.colors.primary)
                        : null,
                    onTap: () {
                      onCategoryChanged(c.id);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimeSheet(BuildContext context) {
    final gt = GlassTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: gt.colors.surface,
      builder: (ctx) => SafeArea(
        child: GlassCard(
          level: 2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in _TimeFilter.values)
                ListTile(
                  title: Text(_timeLabel(f) == '时间' ? '不限' : _timeLabel(f)),
                  trailing: timeFilter == f
                      ? Icon(Icons.check, color: gt.colors.primary)
                      : null,
                  onTap: () {
                    onTimeChanged(f);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 发现页列表卡片。
class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final distance = post.location?.city ?? '同城';

    return GlassCard(
      level: 1,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          // 左侧图片
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16)),
            child: SizedBox(
              width: 110,
              height: 120,
              child: post.images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: post.images.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: gt.colors.glassL2Bg),
                      errorWidget: (_, __, ___) => _defaultThumb(gt),
                    )
                  : _defaultThumb(gt),
            ),
          ),
          // 右侧信息
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gt.colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          post.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: gt.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 11,
                          color: gt.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: gt.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 13, color: gt.colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        post.time != null
                            ? DateFormat('M月d日 HH:mm').format(post.time!)
                            : '待定',
                        style: TextStyle(
                          fontSize: 12,
                          color: gt.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.people_outline,
                          size: 13, color: gt.colors.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${post.acceptedCount}/${post.totalSlots}',
                        style: TextStyle(
                          fontSize: 12,
                          color: gt.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 标签
                  Wrap(
                    spacing: 6,
                    children: [
                      _miniTag(post.costType.label, gt),
                      if (post.isSocialAnxietyFriendly)
                        _miniTag('社恐友好', gt),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultThumb(GlassThemeData gt) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gt.colors.accent, gt.colors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.celebration, color: Colors.white54, size: 32),
      ),
    );
  }

  Widget _miniTag(String label, GlassThemeData gt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gt.colors.glassL2Bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gt.colors.glassL2Border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: gt.colors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

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
            const Text('🔍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              '没找到匹配的局',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '试试调整筛选条件',
              style: TextStyle(color: gt.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
