# task-search — 实现说明

> 负责：frontend-dev
> 日期：2026-04-09
> 状态：DONE（待 reviewer 审查 RD-1/RD-2/RD-3）

## 一、概览

按 researcher T1d 方案 A 落地 Algolia 客户端搜索：
`algolia_helper_flutter` → `HitsSearcher` → `Stream<List<Post>>` → `StreamProvider.family`
→ `SearchScreen` 三态 UI + 300ms debounce，全链路无 Notifier / freezed / `.instance`。

## 二、最终文件清单

### 新增
| 文件 | 说明 |
|------|------|
| `client/lib/data/repositories/search_repository.dart` | `HitsSearcher` Provider + `SearchRepository` + `SearchQuery` + `searchResultsProvider` |
| `client/lib/presentation/features/search/search_screen.dart` | 搜索页 UI，三态 + debounce + 清除 + 回车提交 |
| `client/test/data/repositories/search_repository_test.dart` | `Post.fromAlgoliaHit` + `SearchQuery` 单测（共 8 个 case） |
| `client/test/presentation/features/search/search_screen_test.dart` | widget smoke：渲染 / 输入框 / 空态 / 清除键 |
| `.plans/dazi-app/frontend-dev/task-search/task_plan.md` | 本任务计划 |
| `.plans/dazi-app/frontend-dev/task-search/findings.md` | 本文件 |
| `.plans/dazi-app/frontend-dev/task-search/progress.md` | 日志 |

### 修改
| 文件 | 变更 |
|------|------|
| `client/pubspec.yaml` | `+ algolia_helper_flutter: ^0.7.0` |
| `client/lib/data/models/post.dart` | `+ factory Post.fromAlgoliaHit(Map<String,dynamic>)` |
| `client/lib/core/router/app_router.dart` | `+ GoRoute('/search')` + import |
| `client/lib/presentation/features/home/home_screen.dart` | 搜索框 `onTap: () {}` → `context.push('/search')` |
| `.plans/dazi-app/docs/architecture.md` | §7 搜索章节：「缺失」→「已接入 algolia_helper_flutter」含文件/INV-9/dart-define |
| `.plans/dazi-app/docs/api-contracts.md` | §6 前端路由表追加 `/search` |
| `.plans/dazi-app/docs/invariants.md` | `+ INV-9`：Algolia search key 必须 `--dart-define` 注入 |
| `.plans/dazi-app/frontend-dev/findings.md` | 追加 task-search 索引条目 |

## 三、版本选型

- `algolia_helper_flutter: ^0.7.0`
- 说明：研究层只给出 0.x 策略，未强制版本号。0.7.x 系列是 2024-2025 官方 Dart helper 的主流稳定线，
  与 Flutter SDK `^3.6.2` + Dart `>=2.17` 兼容。若 `flutter pub get` 时解析失败，
  dev 需现场在 pub.dev 查最新 0.x 稳定版替换后重跑 CI（约束条件：仅允许同 major 调整）。

## 四、`Post.fromAlgoliaHit` 字段映射表

| Algolia 字段 | 类型 | 映射到 `Post` | 转换 |
|---|---|---|---|
| `objectID` | string | `id` | 原样 |
| `title` | string | `title` | 默认 `''` |
| `description` | string | `description` | 默认 `''` |
| `category` | string | `category` | 默认 `''` |
| `locationName` | string | `location.name` | 若 `name/city/_geoloc` 均空 → `location = null` |
| `city` | string | `location.city` | 空串归 `null` |
| `_geoloc.lat` / `_geoloc.lng` | num | `location.lat` / `.lng` | `.toDouble()` |
| `time` | int ms | `time` | **`DateTime.fromMillisecondsSinceEpoch`**（区别于 Firestore 的 Timestamp） |
| `costType` | string | `costType` | `CostType.fromString` |
| `isSocialAnxietyFriendly` | bool | 同名 | 默认 `false` |
| `isInstant` | bool | 同名 | 默认 `false` |
| `status` | string | `status` | `PostStatus.fromString` |
| `totalSlots` | num | `totalSlots` | `.toInt()` |
| `createdAt` | int ms | `createdAt` | **`DateTime.fromMillisecondsSinceEpoch`** |

**未同步字段给默认值**：`userId=''`、`images=const []`、`minSlots=2`、`genderQuota=null`、
`acceptedGender=GenderCount(0,0)`、`depositAmount=0`、`waitlist=const []`、`expiresAt=null`、`shareUrl=null`。

> 搜索结果进详情页后，会通过 `postByIdProvider` 从 Firestore 拉完整文档，
> Algolia-only 的 Post 只用于列表展示。

## 五、三态 UI 结构描述

（无法渲染截图，描述 widget 树）

```
Scaffold(backgroundColor: AppColors.background)
├── AppBar
│   ├── BackButton (AppColors.textPrimary)
│   └── title: Container(surfaceAlt, radius 19)
│       └── Row
│           ├── Icon.search (textTertiary)
│           ├── TextField (autoFocus, onChanged→300ms debounce, onSubmitted→立即)
│           │    hint: '搜搭子 试试"火锅""爬山"'
│           └── [当 text 非空] Icon.cancel → _clear()
└── body: 根据 _submittedQuery 分支
    ├── 空 query  → _SearchEmptyHint
    │   Column(center): Icon.search 56 + '找你想要的搭子' + '试试"周末爬山""看展""撸猫"'
    ├── ref.watch(searchResultsProvider(SearchQuery(query, city))).when
    │   ├── loading → _SearchLoading
    │   │   CircularProgressIndicator(valueColor: AppColors.primary)
    │   ├── error → _SearchError
    │   │   Icon.error_outline + '搜索失败' + 错误文本 + ElevatedButton('重试')→ref.refresh
    │   └── data
    │       ├── 空列表 → _SearchNoResults
    │       │   '🔍' + '没有找到相关搭子' + '试试其他关键词吧'
    │       └── 非空 → GridView.builder (crossAxisCount: 2, mainAxisExtent: 290)
    │           使用 PostCard（复用首页 widget，视觉一致 RD-1）
```

## 六、风格/约束自检

| 约束 | 符合 | 证据 |
|---|---|---|
| SD-1 仅 Provider + StreamProvider | OK | search_repository.dart 只定义 `Provider` / `StreamProvider.family`；SearchScreen 用 `ConsumerStatefulWidget + setState` |
| SD-2 SDK 走 Provider 注入 | OK | `HitsSearcher` 在 `algoliaSearcherProvider` 内构造；`ref.onDispose(searcher.dispose)` 生命周期管理 |
| SD-3 `AsyncValue.when` | OK | SearchScreen `resultsAsync.when(loading/error/data)` |
| SD-4 无 freezed / codegen | OK | `SearchQuery` 手写 `==` / `hashCode`，模式同 `FeedQuery` |
| 颜色走 AppColors | OK | 无 `Color(0xFF...)` 硬编码 |
| API key 不硬编码 | OK | `String.fromEnvironment('ALGOLIA_APP_ID' / 'ALGOLIA_SEARCH_KEY')`，CI GR-2 PASS |
| 三态 + debounce + 清除 + 键盘回车 | OK | 见 §五 |
| `PostCard` 视觉复用 | OK | import 自 `features/home/widgets/post_card.dart` |

## 七、决策与风险

1. **debounce 时长 300ms**：对齐方案 A 常规体验。用 `Timer?` + `setState`，不引新工具。
2. **facet filters**：用 `FacetFilterGroup(FilterGroupID('search'), {Filter.facet('city', city), ...})`。Dashboard 尚需把 `city` / `category` 配成 `attributeForFaceting: filterOnly(...)`（backend-dev 任务）。
3. **默认 city 过滤**：从 `currentAppUserProvider` 读；未登录或空城市则不加 facet。
4. **错误态重试**：`ref.refresh(searchResultsProvider(...))`。
5. **HitsSearcher 生命周期**：单例 Provider + `ref.onDispose(searcher.dispose)`。
6. **Post 非搜索字段默认**：列表渲染只用 title/description/category/location/time/totalSlots/status；详情页通过 `postByIdProvider` 从 Firestore 补全。
7. **风险 — HitsSearcher 响应式共享 Stream**：所有 `searchResultsProvider(X)` 共享同一个 `HitsSearcher.responses`。MVP 只有一个 SearchScreen 同时活跃，可接受；若后续加多面板搜索，需每 query 独立 `HitsSearcher`。

## 八、测试摘要

- `search_repository_test.dart`：
  - Post.fromAlgoliaHit 完整字段（全字段填充）
  - 空字段 hit → 安全默认值
  - 只有 locationName → location 构造 + lat/lng null
  - 只有 _geoloc → location 构造
  - num→int/double 转换容错（整数坐标、double totalSlots）
  - SearchQuery 相等性（相同 / query 不同 / city 不同 / category 不同）
- `search_screen_test.dart`：
  - smoke：TextField + BackButton + 空态文案
  - 输入 "火锅" 后 Icon.cancel 出现

> 按任务要求不 mock `HitsSearcher` —— 它是 SDK 行为。测试覆盖的是我们自己的映射层。

## 九、CI 输出

运行：`python scripts/run_ci.py`

```
============================================================
Golden Rules Check
============================================================

[GR-1] File Size Check
  [OK] All files within size limits.

[GR-2] Hardcoded Secrets Check
  [OK] No hardcoded secrets detected.

[GR-3] Console Log Check
  [WARN] functions/src/ai.js:291,295
  [WARN] functions/src/antiGhosting.js:58,185,218,282,287
  [WARN] functions/src/applications.js:223
  （全部 8 条均在 functions/src/*.js — 预存在问题，与 task-search 无关；
    task-search 的 client/ 新增代码 0 命中 console.log/print）

[GR-4] Doc Freshness Check
  [OK] All docs appear fresh.

[GR-5] Invariant Coverage Check
  [OK] All invariants have test coverage (or no invariants defined).

Golden Rules Summary: 0 FAIL, 8 WARN, 0 INFO
Result: PASSED with warnings

[2/3] Flutter 测试：FileNotFoundError
  —— flutter CLI 未在沙箱 PATH 中，无法在本环境执行。
  本地跑法：
    cd client && flutter pub get && flutter test \
      --dart-define=ALGOLIA_APP_ID=test \
      --dart-define=ALGOLIA_SEARCH_KEY=test
```

### CI 结论
- **GR-2（硬编码密钥）PASS** — `String.fromEnvironment` 生效
- **GR-3（console.log/print）** — task-search 新增代码 0 命中；8 条 WARN 全部在 `functions/src/*.js`，是预存在问题
- **GR-4/GR-5 PASS**
- **Flutter 测试无法在沙箱执行**（Flutter CLI 未安装）
- 新增测试不依赖 Algolia 真实连接（空 query → 直接返回 `Stream.value(const [])`，不触发 HitsSearcher）

## 十、部署前置（交给 backend-dev / ops）

- Algolia Dashboard：`posts` 索引配置 `attributesForFaceting = [filterOnly(city), filterOnly(category), costType, isSocialAnxietyFriendly, isInstant]`
- Search-only key 生成，限流 1000/hr/IP，`maxHitsPerQuery=50`
- CI / 本地启动脚本追加：
  `flutter run --dart-define=ALGOLIA_APP_ID=<app_id> --dart-define=ALGOLIA_SEARCH_KEY=<search_key>`

---

[REVIEW-REQUEST] 需要 reviewer 审查 RD-1（UI 精美度与视觉一致性）/ RD-2（产品深度 —— 空查询/空结果/错误/慢网络/键盘）/ RD-3（Firebase 成本与性能 —— HitsSearcher 生命周期与请求合并）。
