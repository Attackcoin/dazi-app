# task-search — 进度日志

## 2026-04-09

- 读取必读文档：algolia-client findings、riverpod-patterns findings、CLAUDE.md 风格决策、algoliaSync.js、post 模型、post_repository、home_screen、app_router、pubspec
- 盘点目标：9 项实施清单
- 风格基线确认：仅 Provider + StreamProvider.family；AsyncValue.when；手写 SearchQuery ==/hashCode（参考 FeedQuery）
- 注意：`HitsSearcher` 需要 `ref.onDispose` 释放
- 关键点：Algolia record 中 `time` / `createdAt` 是 int ms，需要 `Timestamp.fromMillisecondsSinceEpoch`（最终保存为 DateTime）
- 落盘顺序：pubspec → Post 模型 → Repository → SearchScreen → router → home 跳转 → 测试 → 文档 → CI
- 完成编码，运行 CI（详见 findings.md 末尾）

## 2026-04-09 返修（review-search BLOCK-1 + RD-5）

- BLOCK-1 修复：`search_repository.dart` 重写为 family-scoped searcher
  - 删除 `algoliaSearcherProvider`（全局单例 Provider<HitsSearcher>）
  - 删除 `searchRepositoryProvider` + `SearchRepository` 类（只被 searchResultsProvider 用）
  - `searchResultsProvider.family` body 内 new HitsSearcher + ref.onDispose(searcher.dispose)
  - facet 逻辑、空 query 空 Stream、SearchQuery ==/hashCode、Post.fromAlgoliaHit 全部保留不变
- RD-5 Semantics 补标签：
  - 搜索框 Icons.search → `semanticLabel: '搜索'`
  - 清除按钮 GestureDetector + Icons.cancel → 外包 `Semantics(button: true, label: '清除搜索', ...)`
- 测试同步：`search_repository_test.dart` 不引用被删符号，无需改动；`search_screen_test.dart` 未引用被删符号，无需改动
- CI：`python scripts/run_ci.py` 黄金原则 PASS（8 WARN 均为既有 GR-CONSOLE，位于 functions/，与 T2a 无关，无新增 hit）。Flutter CLI 沙箱未装，跳过 flutter test。
- WARN-1..4 按任务范围明确延后，不触碰
