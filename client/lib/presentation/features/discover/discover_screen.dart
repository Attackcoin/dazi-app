import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
import '../../../data/repositories/search_repository.dart';
import '../../../data/services/location_service.dart';

String _costTypeLabel(AppLocalizations l10n, CostType t) => switch (t) {
  CostType.aa => l10n.costType_aa,
  CostType.host => l10n.costType_host,
  CostType.self => l10n.costType_self,
  CostType.tbd => l10n.costType_tbd,
};

/// 发现页 —— 列表形式展示所有局，支持筛选。
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

/// 附近搜索半径选项（公里 → 米）。
const _radiusOptions = <int>[1, 3, 5, 10, 25];
const _defaultRadiusKm = 5;

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _category = '';
  _TimeFilter _timeFilter = _TimeFilter.all;
  bool _verifiedOnly = false;
  bool _nearbyMode = false;
  int _radiusKm = _defaultRadiusKm;

  /// 切换"附近"模式 —— 首次开启时触发定位。
  void _toggleNearby() {
    setState(() {
      _nearbyMode = !_nearbyMode;
      if (_nearbyMode) {
        // 触发定位（如果尚未加载）
        ref.read(currentLocationProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final city = appUser?.city.isNotEmpty == true ? appUser!.city : null;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <CategoryConfig>[];

    // 附近模式：用 Algolia geo search；否则用 Firestore feed
    final locationAsync = _nearbyMode
        ? ref.watch(currentLocationProvider)
        : null;

    return Scaffold(
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.discover_title),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_outlined),
            tooltip: l10n.voice_title,
            onPressed: () => context.push('/voice'),
          ),
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: l10n.venue_title,
            onPressed: () => context.push('/venues'),
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: l10n.circle_title,
            onPressed: () => context.push('/circles'),
          ),
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
              verifiedOnly: _verifiedOnly,
              nearbyMode: _nearbyMode,
              radiusKm: _radiusKm,
              onCategoryChanged: (v) => setState(() => _category = v),
              onTimeChanged: (v) => setState(() => _timeFilter = v),
              onVerifiedChanged: (v) => setState(() => _verifiedOnly = v),
              onNearbyToggled: _toggleNearby,
              onRadiusChanged: (v) => setState(() => _radiusKm = v),
            ),
            // 列表
            Expanded(
              child: _nearbyMode
                  ? _buildNearbyContent(gt, l10n, locationAsync!)
                  : _buildFeedContent(gt, l10n, city),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedContent(GlassThemeData gt, AppLocalizations l10n, String? city) {
    final query = FeedQuery(
      city: city,
      category: _category.isEmpty ? null : _category,
    );
    final feedAsync = ref.watch(feedProvider(query));
    return feedAsync.when(
      data: (posts) {
        final filtered = _applyLocalFilters(posts);
        if (filtered.isEmpty) return const _EmptyState();
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(gt, l10n, () => ref.invalidate(feedProvider(query))),
    );
  }

  Widget _buildNearbyContent(
    GlassThemeData gt,
    AppLocalizations l10n,
    AsyncValue<LocationResult?> locationAsync,
  ) {
    return locationAsync.when(
      data: (loc) {
        if (loc == null) {
          // 定位失败 —— 提示用户
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 48, color: gt.colors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.location_permissionDenied,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: gt.colors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(currentLocationProvider),
                    child: Text(l10n.common_retry),
                  ),
                ],
              ),
            ),
          );
        }
        // 定位成功 —— 用 Algolia geo search
        final searchQuery = SearchQuery(
          query: '', // 空 query 搜全部，靠 geo 排序
          category: _category.isEmpty ? null : _category,
          lat: loc.lat,
          lng: loc.lng,
          radiusMeters: _radiusKm * 1000,
        );
        return _buildNearbyResults(gt, l10n, searchQuery);
      },
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.location_locating, style: TextStyle(color: gt.colors.textSecondary)),
          ],
        ),
      ),
      error: (e, _) => _buildErrorState(gt, l10n, () => ref.invalidate(currentLocationProvider)),
    );
  }

  Widget _buildNearbyResults(
    GlassThemeData gt,
    AppLocalizations l10n,
    SearchQuery searchQuery,
  ) {
    // 附近搜索：geo 模式下 searchResultsProvider 允许空 query，
    // Algolia 返回全部结果并按距离排序。
    final nearbyQuery = SearchQuery(
      query: '',
      category: searchQuery.category,
      lat: searchQuery.lat,
      lng: searchQuery.lng,
      radiusMeters: searchQuery.radiusMeters,
    );
    final resultsAsync = ref.watch(searchResultsProvider(nearbyQuery));
    return resultsAsync.when(
      data: (posts) {
        final filtered = _applyLocalFilters(posts);
        if (filtered.isEmpty) return const _EmptyState();
        return RefreshIndicator(
          color: gt.colors.primary,
          onRefresh: () async {
            ref.invalidate(currentLocationProvider);
            ref.invalidate(searchResultsProvider(nearbyQuery));
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _buildErrorState(gt, l10n, () {
        ref.invalidate(searchResultsProvider(nearbyQuery));
      }),
    );
  }

  Widget _buildErrorState(GlassThemeData gt, AppLocalizations l10n, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: gt.colors.textTertiary),
          const SizedBox(height: 12),
          Text(l10n.common_loadFailed),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: Text(l10n.common_retry),
          ),
        ],
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
    required this.verifiedOnly,
    required this.nearbyMode,
    required this.radiusKm,
    required this.onCategoryChanged,
    required this.onTimeChanged,
    required this.onVerifiedChanged,
    required this.onNearbyToggled,
    required this.onRadiusChanged,
  });

  final List<CategoryConfig> categories;
  final String selectedCategory;
  final _TimeFilter timeFilter;
  final bool verifiedOnly;
  final bool nearbyMode;
  final int radiusKm;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<_TimeFilter> onTimeChanged;
  final ValueChanged<bool> onVerifiedChanged;
  final VoidCallback onNearbyToggled;
  final ValueChanged<int> onRadiusChanged;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
            // 附近 — PillTag（T5-04 GeoSearch）
            PillTag(
              label: nearbyMode
                  ? l10n.discover_nearbyRadius(radiusKm)
                  : l10n.discover_nearby,
              selected: nearbyMode,
              onTap: nearbyMode
                  ? () => _showRadiusSheet(context)
                  : onNearbyToggled,
            ),
            if (nearbyMode) ...[
              const SizedBox(width: 4),
              // 关闭附近模式的小按钮
              GestureDetector(
                onTap: onNearbyToggled,
                child: Icon(Icons.close, size: 16, color: gt.colors.textTertiary),
              ),
            ],
            const SizedBox(width: 8),
            // 分类筛选 — PillTag
            PillTag(
              label: selectedCategory.isEmpty ? l10n.discover_allCategories : selectedCategory,
              selected: selectedCategory.isNotEmpty,
              onTap: () => _showCategorySheet(context),
            ),
            const SizedBox(width: 8),
            // 时间筛选 — PillTag
            PillTag(
              label: _timeLabel(context, timeFilter),
              selected: timeFilter != _TimeFilter.all,
              onTap: () => _showTimeSheet(context),
            ),
            const SizedBox(width: 8),
            // 已验证筛选 — PillTag
            PillTag(
              label: l10n.discover_verifiedOnly,
              color: gt.colors.info,
              selected: verifiedOnly,
              onTap: () => onVerifiedChanged(!verifiedOnly),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(BuildContext context, _TimeFilter f) {
    final l10n = AppLocalizations.of(context)!;
    switch (f) {
      case _TimeFilter.all:
        return l10n.discover_timeAll;
      case _TimeFilter.today:
        return l10n.discover_timeToday;
      case _TimeFilter.thisWeek:
        return l10n.discover_timeThisWeek;
      case _TimeFilter.thisMonth:
        return l10n.discover_timeThisMonth;
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
                title: Text(AppLocalizations.of(context)!.discover_allCategories),
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
                  title: Text(f == _TimeFilter.all ? AppLocalizations.of(context)!.discover_timeNoLimit : _timeLabel(context, f)),
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

  void _showRadiusSheet(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
              for (final km in _radiusOptions)
                ListTile(
                  title: Text(l10n.discover_nearbyRadius(km)),
                  trailing: radiusKm == km
                      ? Icon(Icons.check, color: gt.colors.primary)
                      : null,
                  onTap: () {
                    onRadiusChanged(km);
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
    final l10n = AppLocalizations.of(context)!;
    final distance = post.location?.city ?? l10n.common_sameCity;

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
                            ? DateFormat('M/d HH:mm').format(post.time!)
                            : l10n.common_tbd,
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
                      _miniTag(_costTypeLabel(l10n, post.costType), gt),
                      if (post.isSocialAnxietyFriendly)
                        _miniTag(l10n.discover_socialAnxietyFriendly, gt),
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
              AppLocalizations.of(context)!.discover_emptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.discover_emptyHint,
              style: TextStyle(color: gt.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
