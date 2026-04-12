import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/models/category_config.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/location_service.dart';
import 'widgets/post_card.dart';

const _cnCities = [
  '上海', '北京', '广州', '深圳', '杭州', '成都', '南京', '武汉', '西安', '重庆',
];

const _globalCities = [
  'Tokyo', 'Seoul', 'Singapore', 'Bangkok',
  'New York', 'London', 'Paris', 'Sydney',
];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _category = '';

  Future<void> _onRefresh(FeedQuery query) async {
    ref.invalidate(feedProvider(query));
    try {
      await ref.read(feedProvider(query).future);
    } catch (_) {
      // 失败由 feedAsync.error 分支展示，这里吞掉避免刷新指示器抛错
    }
  }

  Future<void> _showCityPicker(String? current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => _CityPickerSheet(
          current: current,
          scrollController: scrollCtrl,
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    try {
      await ref.read(userRepositoryProvider).updateProfile({'city': picked});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('切换城市失败，请稍后重试')),
      );
    }
  }

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

    return GlowBackground(
      child: RefreshIndicator(
        color: gt.colors.primary,
        onRefresh: () => _onRefresh(query),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              titleSpacing: Spacing.space20,
              title: Row(
                children: [
                  Semantics(
                    button: true,
                    label: '切换城市，当前${city ?? "未选择"}',
                    child: InkWell(
                      onTap: () => _showCityPicker(city),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Icon(Icons.location_on,
                              color: gt.colors.primary, size: 18),
                          const SizedBox(width: Spacing.space4),
                          Text(
                            city ?? '选择城市',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: gt.colors.textPrimary,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down,
                              size: 18, color: gt.colors.textPrimary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.space16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.space12),
                        decoration: BoxDecoration(
                          color: gt.colors.glassL1Bg,
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: gt.colors.glassL1Border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search,
                                size: 18, color: gt.colors.textTertiary),
                            const SizedBox(width: 6),
                            Text(
                              '搜搭子',
                              style: TextStyle(
                                color: gt.colors.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: _CategoryTabs(
                  categories:
                      ref.watch(categoriesProvider).valueOrNull ?? const [],
                  selected: _category,
                  onSelected: (v) => setState(() => _category = v),
                ),
              ),
            ),
            feedAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyFeed(),
                  );
                }
                return SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(Spacing.space16, Spacing.space8, Spacing.space16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: Spacing.space12,
                      crossAxisSpacing: Spacing.space12,
                      mainAxisExtent: 308,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => AnimatedListItem(
                        index: i,
                        child: PostCard(
                          post: posts[i],
                          onTap: () => context.push('/post/${posts[i].id}'),
                        ),
                      ),
                      childCount: posts.length,
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    Spacing.space16, Spacing.space8, Spacing.space16, 100),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Spacing.space12,
                    crossAxisSpacing: Spacing.space12,
                    mainAxisExtent: 308,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => const PostCardSkeleton(),
                    childCount: 6,
                  ),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: gt.colors.textTertiary),
                        const SizedBox(height: Spacing.space12),
                        Text(
                          '加载失败，请检查网络后重试',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: gt.colors.textSecondary),
                        ),
                        const SizedBox(height: Spacing.space16),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(feedProvider(query)),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<CategoryConfig> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // "推荐"永远在第一位，对应空字符串
    final tabs = [
      ('', '推荐'),
      ...categories.map((c) => (c.id, c.label)),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.space16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.space8),
        itemBuilder: (_, i) {
          final (value, label) = tabs[i];
          final isSelected = value == selected;
          return Center(
            child: PillTag(
              label: label,
              selected: isSelected,
              onTap: () => onSelected(value),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: Spacing.space16),
            Text(
              '附近还没有搭子',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.space4),
            Text(
              '成为第一个发起的人吧',
              style: TextStyle(color: gt.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 城市选择底部弹窗 —— 自动定位 + 中国/全球热门 + 手动输入。
class _CityPickerSheet extends ConsumerStatefulWidget {
  const _CityPickerSheet(
      {required this.current, required this.scrollController});

  final String? current;
  final ScrollController scrollController;

  @override
  ConsumerState<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends ConsumerState<_CityPickerSheet> {
  bool _locating = true; // 打开弹窗就自动定位
  String? _detectedCity;

  @override
  void initState() {
    super.initState();
    _autoLocate();
  }

  Future<void> _autoLocate() async {
    try {
      final result =
          await ref.read(locationServiceProvider).getCurrentCity();
      if (!mounted) return;
      if (result != null) {
        setState(() => _detectedCity = result.city);
      }
    } catch (_) {
      // 定位失败静默，用户手动选
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return GlassCard(
      level: 2,
      useBlur: true,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Radii.sheet),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.space20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.space12),
            child: Text(
              '选择城市',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: gt.colors.textPrimary,
              ),
            ),
          ),
          // 自动定位结果
          if (_locating)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.space16, vertical: Spacing.space12),
              margin: const EdgeInsets.only(bottom: Spacing.space16),
              decoration: BoxDecoration(
                color: gt.colors.glassL1Bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gt.colors.glassL1Border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: gt.colors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text('正在定位...',
                      style: TextStyle(
                          fontSize: 14, color: gt.colors.textSecondary)),
                ],
              ),
            )
          else if (_detectedCity != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.space16),
              child: ListTile(
                leading:
                    Icon(Icons.my_location, color: gt.colors.primary),
                title: Text(_detectedCity!,
                    style:
                        TextStyle(color: gt.colors.textPrimary)),
                subtitle: Text('当前位置',
                    style: TextStyle(
                        fontSize: 12, color: gt.colors.textSecondary)),
                tileColor: gt.colors.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => Navigator.of(context).pop(_detectedCity),
              ),
            ),
          // 手动输入
          TextField(
            decoration: const InputDecoration(
              hintText: '输入城市名 / Enter city name',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onSubmitted: (v) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty) Navigator.of(context).pop(trimmed);
            },
          ),
          const SizedBox(height: Spacing.space20),
          Text(
            '中国',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: gt.colors.textSecondary,
            ),
          ),
          const SizedBox(height: Spacing.space8),
          ..._cnCities.map((c) => _cityTile(gt, c)),
          const SizedBox(height: Spacing.space16),
          Text(
            'Global',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: gt.colors.textSecondary,
            ),
          ),
          const SizedBox(height: Spacing.space8),
          ..._globalCities.map((c) => _cityTile(gt, c)),
          const SizedBox(height: Spacing.space24),
        ],
      ),
    );
  }

  Widget _cityTile(GlassThemeData gt, String city) {
    final selected = city == widget.current;
    return ListTile(
      dense: true,
      title:
          Text(city, style: TextStyle(color: gt.colors.textPrimary)),
      trailing: selected
          ? Icon(Icons.check, color: gt.colors.primary)
          : null,
      onTap: () => Navigator.of(context).pop(city),
    );
  }
}
