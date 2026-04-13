# task-search — 实施计划

> 负责：frontend-dev
> 日期：2026-04-09
> 状态：in-progress

## 目标
接入 Algolia 客户端搜索（方案 A `algolia_helper_flutter`），
首页搜索框 onTap → `/search`，提供完整 loading / empty / error 三态，
严格遵循 SD-1~SD-4 风格约束。

## 依赖文档
- 主调研：`.plans/dazi-app/researcher/research-algolia-client/findings.md`
- 风格基线：`.plans/dazi-app/researcher/research-riverpod-patterns/findings.md`
- 审查维度：`CLAUDE.md` RD-1~RD-5

## 实施清单

| # | 任务 | 状态 | 文件 |
|---|------|------|------|
| 1 | `pubspec.yaml` 添加 `algolia_helper_flutter` | DONE | `client/pubspec.yaml` |
| 2 | `Post.fromAlgoliaHit` 工厂 | DONE | `client/lib/data/models/post.dart` |
| 3 | `SearchRepository` + providers | DONE | `client/lib/data/repositories/search_repository.dart` |
| 4 | `SearchScreen` UI（三态 + debounce） | DONE | `client/lib/presentation/features/search/search_screen.dart` |
| 5 | `searchResultsProvider` + `SearchQuery` | DONE | 合并进 search_repository.dart |
| 6 | 路由 `/search` 注册 | DONE | `client/lib/core/router/app_router.dart` |
| 7 | 首页搜索框 onTap 跳转 | DONE | `client/lib/presentation/features/home/home_screen.dart` |
| 8 | 单测 + widget 测试 | DONE | `client/test/data/repositories/search_repository_test.dart`、`client/test/presentation/features/search/search_screen_test.dart` |
| 9 | 文档同步（architecture/api-contracts/invariants） | DONE | `.plans/dazi-app/docs/*` |
| 10 | CI 运行并附输出 | DONE | findings.md 末尾 |

## 风格自检
- [x] 不使用 Notifier/StateNotifier/ChangeNotifier（SD-1）
- [x] 所有 SDK 走 Provider 注入（SD-2）
- [x] 使用 AsyncValue + .when（SD-3）
- [x] 不引入 freezed / riverpod_generator（SD-4）
- [x] 颜色走 AppColors
- [x] Algolia key 通过 `String.fromEnvironment`，禁止硬编码
