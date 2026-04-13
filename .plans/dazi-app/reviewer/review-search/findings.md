# review-search — 审查报告

> 任务：T2a 搜索功能接入（Algolia）代码审查
> 执行：reviewer
> 日期：2026-04-09
> 状态：complete

## 1. 总体裁决

**[BLOCK]**

1 个 BLOCK（HitsSearcher 竞态）+ 5 个 WARN + 4 个 INFO + 1 个 AUTOMATE。RD-5 可访问性 WEAK。

## 2. 各维度评分

| # | 维度 | 评分 | 理由 |
|---|------|------|------|
| RD-1 | UI 精美度与视觉一致性 | ADEQUATE | 三态齐全、PostCard 复用、AppColors 基本到位；但 `_SearchError` 裸 `Colors.white`、错误图标用 `textTertiary` 灰色 |
| RD-2 | 产品深度（边界情况）| ADEQUATE | 空 query 拦截 / debounce / 清除按钮都有；但 family 竞态（BLOCK-1）、键盘遮挡未显式处理 |
| RD-3 | Firebase/Algolia 成本与性能 | ADEQUATE | `--dart-define` 注入符合 INV-9、`ref.onDispose` 存在；`hitsPerPage=30` 与 T1d 建议 50 略偏差；无分页 |
| RD-4 | 测试覆盖与可维护性 | ADEQUATE | fromAlgoliaHit 5 case + SearchQuery 相等性齐全；缺 loading/error widget 测试和 SearchRepository 集成测试 |
| RD-5 | 可访问性与国际化 | **WEAK** | 搜索框图标、清除按钮无 Semantics；所有文案硬编码中文无 i18n key |

> RD-5 WEAK + BLOCK-1 = [BLOCK]

## 3. 风格决策合规（SD-1..SD-4）

| # | 决策 | 判定 | 说明 |
|---|------|------|------|
| SD-1 | 仅 Provider + StreamProvider；UI 本地 setState | PASS | family 用 StreamProvider，debounce Timer+setState |
| SD-2 | Firebase SDK 必须 provider 注入 | PASS | 本任务不涉 Firebase SDK |
| SD-3 | AsyncValue<T> + .when | PASS | `_buildBody` 用 `resultsAsync.when` |
| SD-4 | 不引 freezed / riverpod_generator | PASS | `SearchQuery` 手写 == / hashCode |

## 4. 发现清单

### [BLOCK]

**BLOCK-1：`HitsSearcher` 单例 × `searchResultsProvider.family` 竞态**
- 文件：`client/lib/data/repositories/search_repository.dart:19-27, 75-78, 102-112`
- 根因：`algoliaSearcherProvider` 是全局 `Provider<HitsSearcher>`，持有共享 `responses` Stream。`searchResultsProvider.family` 每个 key 都通过它 `applyState` 并 listen 同一条 Stream。快速切换 query 时，多个 family 实例共享同一 Stream，互相收到对方响应；`ref.refresh` 场景下重复发请求（见 WARN-5）。
- 修复：把 `HitsSearcher` 从全局单例改为 **family-scoped**——在 `searchResultsProvider.family` body 内部 `new HitsSearcher(...)` + `ref.onDispose(searcher.dispose)`，每个 `SearchQuery` key 一个独立 searcher。修复后 `algoliaSearcherProvider` 和 `searchRepositoryProvider` 可移除，WARN-5 一并消失。

```dart
final searchResultsProvider =
    StreamProvider.family<List<Post>, SearchQuery>((ref, q) {
  if (q.query.trim().isEmpty) return Stream.value(const <Post>[]);
  final searcher = HitsSearcher(
    applicationID: _algoliaAppId,
    apiKey: _algoliaSearchKey,
    indexName: _algoliaIndexName,
  );
  ref.onDispose(searcher.dispose);
  searcher.applyState((state) => state.copyWith(
    query: q.query, page: 0, hitsPerPage: 30,
    filterGroups: ...,
  ));
  return searcher.responses
      .map((r) => r.hits.map(Post.fromAlgoliaHit).toList());
});
```

### [WARN]

**WARN-1：`_SearchError` 按钮硬编码 `Colors.white`（违反 INV-7）**
- `client/lib/presentation/features/search/search_screen.dart:291-292`
- `foregroundColor: Colors.white` 裸写；`app_theme.dart` 的 elevatedButtonTheme 已全局配置，此处覆盖冗余。
- 修复：移除 `ElevatedButton.styleFrom` 的 `foregroundColor` / `backgroundColor` 两行，或改为 `AppColors.surface`。

**WARN-2：错误态图标语义色错误**
- `client/lib/presentation/features/search/search_screen.dart:269-270`
- `Icons.error_outline` 用 `AppColors.textTertiary`（灰色），无法传达错误语义。
- 修复：改为 `AppColors.error`。

**WARN-3：widget 测试缺 loading/error 态覆盖**
- `client/test/presentation/features/search/search_screen_test.dart`
- 仅空态 + 清除按钮。T1d §7.3 要求覆盖三态。
- 修复：override `searchResultsProvider` 分别注入 loading（StreamController 不 emit）和 error 状态，验证三态渲染 + retry 按钮可点。

**WARN-4：`resizeToAvoidBottomInset` 未显式，键盘遮挡风险**
- `client/lib/presentation/features/search/search_screen.dart:74`
- `GridView` padding bottom 固定 `24`，小屏设备键盘展开时底部结果可能被遮。
- 修复：Scaffold 显式 `resizeToAvoidBottomInset: true`，或 GridView padding bottom 加 `MediaQuery.viewInsets.bottom`。

**WARN-5：`StreamProvider.family` body 中有副作用（`applyState`）**
- `client/lib/data/repositories/search_repository.dart:107-111`
- StreamProvider body 不应有副作用。`ref.refresh` 会重复触发 `applyState`。
- 修复：随 BLOCK-1 一并修复。

### [INFO]

- **INFO-1**：`hitsPerPage=30` 与 T1d 建议 `maxHitsPerQuery=50` 不一致。客户端 ≤ Dashboard 是合理的，PR 说明里注明
- **INFO-2**：无分页 / infinite scroll。MVP 30 条可接受，backlog
- **INFO-3**：`_SearchNoResults` 文案与空态提示重复；建议"换个关键词试试"+ 返回首页 TextButton
- **INFO-4**：`search_repository_test.dart` 实际只测 `fromAlgoliaHit` + `SearchQuery`，未 mock `HitsSearcher`；建议补 mocktail

### [AUTOMATE]

- **AUTOMATE-1**：INV-9 硬编码检测。custodian 在 `golden_rules.py` GR-2 增加 Algolia key 正则：`*.dart` 匹配 `applicationID.*['"]\w{10,}['"]` 或 `apiKey.*['"]\w{32}['"]`，硬编码 fail CI。

## 5. 是否建议合入

**不建议合入**。必须修复：

1. **BLOCK-1**：HitsSearcher family-scoped 重构
2. **RD-5**：清除按钮 + 搜索图标补 `Semantics`；i18n 若不在 MVP 可由 team-lead 豁免降格 ADEQUATE
3. **WARN-1/2/3**：颜色硬编码 + 错误图标语义色 + 补 loading/error widget 测试

WARN-4/5 随 BLOCK-1 修复顺带处理。
