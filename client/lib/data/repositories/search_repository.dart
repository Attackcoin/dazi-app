import 'package:algolia_helper_flutter/algolia_helper_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';

/// Algolia 应用 ID / Search-only key。
///
/// 必须通过 `--dart-define=ALGOLIA_APP_ID=... --dart-define=ALGOLIA_SEARCH_KEY=...`
/// 注入，**禁止硬编码到源码**（见 invariants INV-3 / INV-9）。
const String _algoliaAppId =
    String.fromEnvironment('ALGOLIA_APP_ID', defaultValue: '');
const String _algoliaSearchKey =
    String.fromEnvironment('ALGOLIA_SEARCH_KEY', defaultValue: '');
const String _algoliaIndexName = 'posts';

/// 搜索查询参数 —— 手写 `==` / `hashCode`（符合 SD-4，不引 freezed）。
/// 参考 `FeedQuery`（post_repository.dart）。
class SearchQuery {
  final String query;
  final String? city;
  final String? category;

  /// 地理搜索参数（Phase A: T5-04 GeoSearch）。
  /// 当 [lat] 和 [lng] 同时有值时启用 Algolia `aroundLatLng` 搜索。
  final double? lat;
  final double? lng;

  /// 搜索半径（米）。为 null 时 Algolia 自动计算密度半径。
  final int? radiusMeters;

  const SearchQuery({
    required this.query,
    this.city,
    this.category,
    this.lat,
    this.lng,
    this.radiusMeters,
  });

  /// 是否启用了地理搜索。
  bool get hasGeo => lat != null && lng != null;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.query == query &&
      other.city == city &&
      other.category == category &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(query, city, category, lat, lng, radiusMeters);
}

/// 搜索结果 Stream Provider —— family-scoped `HitsSearcher`。
///
/// 每个 `SearchQuery` key 独立创建一个 `HitsSearcher`，避免多个 family 实例
/// 共享同一条 `responses` Stream 导致的竞态（BLOCK-1）。Provider 释放时
/// 通过 `ref.onDispose` 调用 `searcher.dispose()`，生命周期与 family key 对齐。
///
/// 空 query 且无地理搜索时直接发空列表，避免无谓请求。
/// 地理搜索模式下允许空 query（Algolia 返回全部结果，按距离排序）。
final searchResultsProvider =
    StreamProvider.family<List<Post>, SearchQuery>((ref, q) {
  if (q.query.trim().isEmpty && !q.hasGeo) {
    return Stream.value(const <Post>[]);
  }

  final searcher = HitsSearcher(
    applicationID: _algoliaAppId,
    apiKey: _algoliaSearchKey,
    indexName: _algoliaIndexName,
  );
  ref.onDispose(searcher.dispose);

  final facetFilters = <FilterFacet>{};
  if (q.city != null && q.city!.isNotEmpty) {
    facetFilters.add(Filter.facet('city', q.city!));
  }
  if (q.category != null && q.category!.isNotEmpty) {
    facetFilters.add(Filter.facet('category', q.category!));
  }

  searcher.applyState(
    (state) => state.copyWith(
      query: q.query,
      page: 0,
      hitsPerPage: 50,
      filterGroups: facetFilters.isEmpty
          ? const <FilterGroup>{}
          : {
              FacetFilterGroup(
                const FilterGroupID('search'),
                facetFilters,
              ),
            },
      // Phase A (T5-04): 地理搜索 —— aroundLatLng 格式 "lat,lng"
      aroundLatLng: q.hasGeo ? '${q.lat},${q.lng}' : null,
      aroundRadius: q.hasGeo ? (q.radiusMeters ?? 'all') : null,
    ),
  );

  return searcher.responses.map(
    (response) => response.hits.map(Post.fromAlgoliaHit).toList(),
  );
});
