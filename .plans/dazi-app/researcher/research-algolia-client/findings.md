# research-algolia-client — 调研报告

> 任务：Flutter 客户端接入 Algolia 搜索的方案对比
> 执行：researcher（阶段 1 T1d）
> 日期：2026-04-09
> 状态：complete

## 工具限制说明
WebFetch / WebSearch / context7 MCP 在沙箱中被拒绝，外部版本号与 Algolia 配额基于模型训练数据（截至 2025-05）。**落地前 dev 需在 pub.dev 与 Algolia Dashboard 现场二次核对**。

---

## 一、关键事实速览

| 项目 | 当前状态 | 证据 |
|------|---------|------|
| Flutter SDK 约束 | `^3.6.2` | `client/pubspec.yaml:7` |
| 状态管理 | `flutter_riverpod ^2.5.1` | `client/pubspec.yaml:15` |
| 路由 | `go_router ^14.6.0` | `client/pubspec.yaml:18` |
| 现有 Posts 读取 | `StreamProvider` + `snapshots()` | `post_repository.dart:18-39` |
| 现有过滤维度 | `status=open` + `location.city` + `category` | `post_repository.dart:23-34` |
| **首页搜索入口** | "搜搭子"输入框已占位，`onTap: () {}` 空壳 | `home_screen.dart:72-97` (第 73 行) |
| Algolia 索引名 | `posts` | `algoliaSync.js:20` |
| Cloud Function region | `asia-southeast1` | `algoliaSync.js:64` |
| 非活跃帖子清理 | `status ∈ {done,cancelled,expired}` 自动 deleteObject | `algoliaSync.js:83-86` |

**关键信号**：首页搜索框 UI 已占位，`onTap` 空壳——产品明确需要搜索，MVP 就要接入，不是可选项。

---

## 二、Algolia 索引字段（`algoliaSync.js:40-59`）

```
objectID, title, description, category,
locationName, city, _geoloc?{lat,lng},
time(ms), costType, isSocialAnxietyFriendly,
isInstant, status, totalSlots, createdAt(ms)
```

**关键**：后端同步层已做 PII 白名单——手机号/openid/FCM token 不入索引。直接决定方案 A 的 Search-only key 暴露风险可控。

**Dashboard 必配**（后续 backend-dev 执行）：
- `searchableAttributes = [title, description, locationName, category]`
- `attributesForFaceting = [filterOnly(city), category, costType, isSocialAnxietyFriendly, isInstant]`
- `customRanking = [desc(createdAt)]`
- `attributesToRetrieve` 显式白名单

---

## 三、三方案对比

### 方案 A：`algolia_helper_flutter`（官方 Dart SDK） ✅ 推荐
- 维护方：Algolia 官方 `algolia/algoliasearch-helper-dart` monorepo
- Dart SDK 要求 `>=2.17`，兼容 `^3.6.2`
- 核心 API：`HitsSearcher` + `FacetList` + `SearchState`（响应式 Stream）

**优点**：MVP 最快；天然贴合 Riverpod Stream 模式；内置 debounce/查询合并/分页/facet；官方维护类型安全；包体积 +200-400 KB 可忽略。

**缺点**：0.x 版本 API 可能微调；Search-only key 需打进客户端（可控）；无运行时业务过滤注入（MVP 不需要）。

### 方案 B：Firebase Function 代理
客户端 `cloud_functions` 调 Callable `searchPosts`，Function 内用 Node `algoliasearch`。

**优点**：key 零暴露；可注入业务过滤（拉黑/敏感词/地理）；未来换引擎客户端零改；统一鉴权埋点。

**缺点**：
1. **延迟翻倍**：客户端→Function（冷启 1-3s / 热启 100-300ms）→Algolia→回程。P50 翻倍，P99 冷启动惩罚，**直接伤 RD-1 UI 品味**
2. **成本双跳**：Functions 调用费 + 出口流量 + Algolia 配额
3. 需自己维护查询 DSL 序列化
4. **MVP 优势用不到**：屏蔽/拉黑系统尚未实现

### 方案 C：手写 HTTP 调 REST
**反模式**。需自实现签名/DSN fallback/重试/error code/facet 序列化/geo DSL，跟进 API 升级负担大。

---

## 四、项目兼容性

1. **SDK 版本**：兼容 OK
2. **Repo 模式同构**：`HitsSearcher.responses` 是 Stream，与 `StreamProvider` 天然适配。建议**新建** `SearchRepository`，不改 `PostRepository`
3. **UI 入口已就位**：`home_screen.dart:73` 只差 `context.push('/search')`
4. **路由**：`go_router` 直接注册 `/search`
5. **Model**：新增 `Post.fromAlgoliaHit(Map<String,dynamic>)` 工厂，注意 `time`/`createdAt` 是 `int` ms 而非 `Timestamp`
6. **视觉一致**：搜索结果页复用 `PostCard` widget → RD-1 STRONG

---

## 五、安全与成本

### 5.1 Search-only key 暴露
- Dashboard 单独生成 Flutter 专用 key
- 配 Rate limit（建议 1000/hr/IP）、`maxHitsPerQuery=50`、索引白名单 `posts`
- **禁硬编码**，`--dart-define` 注入，或 Firebase Remote Config 热下发
- 同步层已滤 PII，泄漏不导致用户隐私外泄

**结论：可安全暴露**，前提 Dashboard 限流到位。

### 5.2 免费额度
- Build（免费）：~10k records + 10k search ops/月（dev 需核对）
- MVP 估算：records 远低于 10k；search 10k/月 ≈ 333/天，DAU 100 × 3 次 = 300/天，刚好吃满
- DAU > 150 后需升级 Grow plan（~$0.50/1k searches）
- 缓解：上线首月每日监控 + 客户端查询合并

### 5.3 敏感字段
同步层白名单 + Dashboard `attributesToRetrieve` 双保险。

---

## 六、推荐方案：A `algolia_helper_flutter`

**理由**（排序）：
1. MVP 最快（1.5 天，B 多 1 天，C 多 3 天）
2. 延迟最低，P50 ~150ms，无冷启动惩罚 → **RD-1 STRONG**
3. 架构零摩擦，Stream 模式同构
4. 成本最低，免费额度对 MVP 够
5. 同步层已过滤 PII，key 暴露风险可控；B 的业务过滤优势 MVP 吃不到
6. 可回退：后续切 B 时 `SearchRepository` 底层换实现，UI 零改

---

## 七、落地步骤清单

### 7.1 Algolia Dashboard（backend-dev，0.5 天）
- [ ] `posts` 索引配置 searchable/faceting/customRanking/attributesToRetrieve
- [ ] 新建 Search-only key，限定 `posts`，rate limit 1000/hr/IP，maxHitsPerQuery=50
- [ ] key 走密码管理器交 frontend-dev

### 7.2 客户端集成（frontend-dev，1.5 天）
- [ ] `pubspec.yaml` 加 `algolia_helper_flutter: ^<现场查 pub.dev>`
- [ ] 新建 `client/lib/data/repositories/search_repository.dart`，暴露 `searchPosts({query, city?, category?})` → `Stream<List<Post>>`
- [ ] `Post` model 加 `factory Post.fromAlgoliaHit(Map<String,dynamic>)`（time/createdAt 是 int ms）
- [ ] 新建 `client/lib/presentation/features/search/search_screen.dart`：TextField + debounce + `PostCard` 列表 + 空/错误/loading 齐全 + 默认继承 `currentAppUserProvider.city`
- [ ] `home_screen.dart:73` 的 `onTap: () {}` → `context.push('/search')`
- [ ] `go_router` 注册 `/search`
- [ ] `--dart-define=ALGOLIA_APP_ID=... ALGOLIA_SEARCH_KEY=...` 注入，**禁硬编码**

### 7.3 测试（frontend-dev + e2e-tester，0.5 天）
- [ ] `SearchRepository` 单测（mock `HitsSearcher`）
- [ ] Widget 测试覆盖空/loading/错误态
- [ ] E2E：首页点搜索框 → 输"火锅" → 看结果 → 点详情
- [ ] `python scripts/run_ci.py` 通过

### 7.4 文档同步（custodian，0.2 天）
- [ ] `docs/architecture.md` 加"搜索"章节
- [ ] `docs/api-contracts.md` 记录 Algolia record schema
- [ ] `docs/invariants.md` 追加："Algolia search key 必须 `--dart-define` 注入"（候选 golden_rules 自动化）

### 7.5 审查（reviewer）
- [ ] 审 RD-1 / RD-2 / RD-3
- [ ] 专项：key 未硬编码、空/错误态、暗色模式、图片缓存

---

## 八、风险与 Follow-up

| 风险 | 缓解 |
|------|------|
| helper 0.x 版本 | `SearchRepository` 封装 |
| 免费额度突破 | Dashboard Usage 监控 + 查询合并 |
| Search-only key 泄漏 | Rate limit + 同步层 PII 过滤 |
| 搜索词脏话/广告 | 后续 Function 敏感词过滤 |
| 拉黑用户帖子仍出现 | 屏蔽系统上线时切到 B |

**升级路径**：DAU > 500 或屏蔽系统上线 → 新增 Callable `searchPosts`，`SearchRepository` 底层切 B，UI 零改；需要"附近搭子"排序 → 用 `_geoloc` + `aroundLatLng`。

---

## 九、结论

**推荐方案 A `algolia_helper_flutter`**，2.5 天落地。首页 UI 占位就位 + 同步管道就位，**落地阻力最小**。
