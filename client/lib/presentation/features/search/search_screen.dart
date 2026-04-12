import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/search_repository.dart';
import '../home/widgets/post_card.dart';

/// 搜索页 —— 接入 Algolia，提供 debounce + 完整三态。
///
/// 遵循 SD-1：`ConsumerStatefulWidget` + `setState` 管理本地 UI（query / debounce
/// 定时器），异步数据走 `ref.watch(searchResultsProvider(...))` + `AsyncValue.when`。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounceDuration = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _submittedQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 进入页面自动聚焦输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // 立即 rebuild 让清除按钮根据 _controller.text 即时显示/隐藏。
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() => _submittedQuery = value.trim());
    });
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    setState(() => _submittedQuery = value.trim());
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _submittedQuery = '');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final appUser = ref.watch(currentAppUserProvider).valueOrNull;
    final city = appUser?.city.isNotEmpty == true ? appUser!.city : null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: gt.colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: BackButton(color: gt.colors.textPrimary),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GlassInput(
            controller: _controller,
            hint: '搜搭子 试试"火锅""爬山"',
            autofocus: false,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
            prefix: Icon(
              Icons.search,
              size: 18,
              color: gt.colors.textTertiary,
              semanticLabel: '搜索',
            ),
            suffix: _controller.text.isNotEmpty
                ? Semantics(
                    button: true,
                    label: '清除搜索',
                    child: GestureDetector(
                      onTap: _clear,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.cancel,
                          size: 18,
                          color: gt.colors.textTertiary,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(city),
    );
  }

  Widget _buildBody(String? city) {
    final gt = GlassTheme.of(context);

    if (_submittedQuery.isEmpty) {
      return _SearchEmptyHint(gt: gt);
    }

    final resultsAsync = ref.watch(
      searchResultsProvider(
        SearchQuery(query: _submittedQuery, city: city),
      ),
    );

    return resultsAsync.when(
      loading: () => _SearchLoading(gt: gt),
      error: (e, _) => _SearchError(
        error: e,
        gt: gt,
        onRetry: () {
          // 通过 refresh 触发重新订阅
          // ignore: unused_result
          ref.refresh(
            searchResultsProvider(
              SearchQuery(query: _submittedQuery, city: city),
            ),
          );
        },
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return _SearchNoResults(gt: gt);
        }
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 290,
          ),
          itemCount: posts.length,
          itemBuilder: (_, i) => AnimatedListItem(
            index: i,
            child: GlassCard(
              level: 1,
              padding: EdgeInsets.zero,
              child: PostCard(
                post: posts[i],
                onTap: () => context.push('/post/${posts[i].id}'),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchEmptyHint extends StatelessWidget {
  const _SearchEmptyHint({required this.gt});

  final GlassThemeData gt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search,
                size: 56,
                color: gt.colors.textTertiary,
                semanticLabel: '搜索提示'),
            const SizedBox(height: 12),
            Text(
              '找你想要的搭子',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '试试"周末爬山""看展""撸猫"',
              style: TextStyle(color: gt.colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchLoading extends StatelessWidget {
  const _SearchLoading({required this.gt});

  final GlassThemeData gt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(gt.colors.primary),
      ),
    );
  }
}

class _SearchNoResults extends StatelessWidget {
  const _SearchNoResults({required this.gt});

  final GlassThemeData gt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              '没有找到相关搭子',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '换个关键词试试',
              style: TextStyle(color: gt.colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.error, required this.onRetry, required this.gt});

  final Object error;
  final VoidCallback onRetry;
  final GlassThemeData gt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: gt.colors.error),
            const SizedBox(height: 12),
            Text(
              '搜索失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: gt.colors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
