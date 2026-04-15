# dazi-app - 团队运营手册

> 由 CCteam-creator 自动生成，可按需修改。
> 此文件让 team-lead 的团队知识在上下文压缩后仍然保持。
> 生成日期: 2026-04-09

## 项目概述

Flutter + Firebase + Algolia 的社交发帖类 App，当前处于 MVP 开发阶段。
技术栈：Flutter（客户端）/ Firebase Functions（Node.js，后端）/ Firestore / Algolia（搜索）/ Firebase Hosting。

## Team-Lead 控制平面

- team-lead = 主对话，不是生成的 agent
- team-lead 负责用户对齐、范围控制、任务分解和阶段推进
- team-lead 维护项目全局真相：主 `task_plan.md`、`decisions.md` 和此 `CLAUDE.md`
- team-lead 决定某个流程改进是项目本地的还是需要写回 `CCteam-creator` 的
- **禁用独立子智能体**：团队存在后，所有工作通过 SendMessage 交给队友。不要启动独立的 Agent/子智能体（Explore、general-purpose 等）——它们绕过团队的规划文件和协作体系。唯一例外：用 `team_name` 生成新队友加入团队

## 团队花名册

| 名称 | 角色 | 模型 | 核心能力 |
|------|------|------|---------|
| backend-dev | 后端开发 | sonnet | Firebase Functions (Node.js) + Firestore 规则 + Algolia 同步 + TDD |
| frontend-dev | 前端开发 | sonnet | Flutter 客户端 + UI 组件 + 状态管理 + 路由 + TDD |
| researcher | 探索/研究 | sonnet | Flutter/Firebase 最佳实践 + 代码搜索 + 网页调研（只读） |
| e2e-tester | 联调测试 | sonnet | Flutter integration test + Playwright + Bug 记录 |
| reviewer | 代码审查 | sonnet | 安全/质量/UI 品味/性能审查（只读源代码） |
| custodian | 管家 | sonnet | 合规巡检 + 文档治理 + 模式→自动化 + 代码清理 |

## 任务下发协议

### TaskCreate 描述格式

TaskCreate 描述：一句话范围 + 验收标准 + `.plans/` 路径。
示例：`"发帖 UI 精调。输入：design tokens 在 .plans/dazi-app/docs/architecture.md §UI Tokens。输出：可用 + widget 测试。详见 .plans/dazi-app/frontend-dev/task-post-polish/task_plan.md"`
通过 TaskUpdate 分配负责人和设置依赖。

### 大任务（功能开发、新模块）-- 停止检查后再发送

**在给任何智能体下发大任务前，检查消息中是否包含以下 4 项。如有缺失，先补上再发。**

1. **范围和目标**：要做什么、验收标准
2. **文档提醒**："请创建 `<前缀>-<任务名>/` 任务文件夹（含 task_plan.md + findings.md + progress.md），并在你的根 findings.md 中添加索引条目"
3. **依赖说明**：依赖哪些调研/任务的结论，关键文件路径和行号
4. **审查预期**：完成后是否需要代码审查

示例：
```
SendMessage(to: "frontend-dev", message:
  "新任务：首页信息流列表。
   范围：Home 页列表 + PostCard widget + 下拉刷新 + 分页加载。
   依赖：researcher 的 Flutter 状态管理调研在 .plans/dazi-app/researcher/research-state-mgmt/findings.md
   请创建 task-home-feed/ 文件夹，并更新你的根 findings.md 索引。
   这是大功能——完成后请找 reviewer 审查。")
```

各角色的任务文件夹前缀：
- backend-dev / frontend-dev：`task-<名称>/`
- researcher：`research-<主题>/`
- e2e-tester：`test-<范围>/`
- reviewer：`review-<目标>/`
- custodian：`audit-<范围>/`

### 小任务（Bug 修复、配置变更）

直接发消息说明改动即可，不需要任务文件夹，也不需要审查。

## 通信速查

| 操作 | 命令 |
|------|------|
| 给单个智能体分配任务 | `SendMessage(to: "<名称>", message: "...")` |
| 广播（慎用） | `SendMessage(to: "*", message: "...")` |
| dev 请求代码审查 | dev 直接联系 reviewer（不经过 team-lead） |

## 状态检查

| 要检查什么 | 怎么做 |
|-----------|--------|
| 全局概览 | `TaskList` |
| 快速扫描 | 并行读各 agent 的 `progress.md` |
| 深入了解 | 读 agent 的 `findings.md`（索引）→ 再看具体任务文件夹 |
| 方向检查 | 读 `.plans/dazi-app/task_plan.md` |
| 恢复项目 | 读 `.plans/dazi-app/team-snapshot.md` → 陈旧检测 → 恢复 agents |

读取顺序：**progress**（到哪了）→ **findings**（遇到什么）→ **task_plan**（目标是什么）

## 文档索引（知识库）

> **导航地图**：`.plans/dazi-app/docs/index.md` 有各文档的 section 级导航。custodian 维护。

| 文档 | 位置 | 维护者 |
|------|------|--------|
| 导航地图 | .plans/dazi-app/docs/index.md | custodian |
| 架构 | .plans/dazi-app/docs/architecture.md | team-lead, devs |
| API 契约 | .plans/dazi-app/docs/api-contracts.md | devs（API 变更时**必须**同步） |
| 不变量 | .plans/dazi-app/docs/invariants.md | team-lead, reviewer |

**Doc-Code Sync 规则**：当代码变更了 API 或架构时，对应的 docs/ 文件**必须**在同一个任务中同步更新。

## 自动化检查

| 检查 | 脚本 | 执行什么 |
|------|------|---------|
| 黄金原则 | scripts/golden_rules.py | 文件大小、密钥、console.log、文档新鲜度、不变量覆盖 |
| CI（测试 + 类型） | scripts/run_ci.py | 黄金原则 + Flutter 测试 + Functions 测试 |

运行：`python scripts/run_ci.py`

## 审查维度

> Reviewer 在每次审查时给各维度打分（STRONG/ADEQUATE/WEAK）。任何维度 WEAK → 不能 [OK]。

| # | 维度 | 权重 | STRONG 表现 | WEAK 表现 |
|---|------|------|-----------|---------|
| RD-1 | **UI 精美度与视觉一致性** | 高 | 严格遵循 Material 3、间距对齐精准、配色一致（走 app_colors）、动画流畅自然、有加载/空/错误状态、暗色模式适配 | 间距随意、颜色硬编码、无空状态、过渡生硬、暗色破版 |
| RD-2 | **产品深度（边界情况）** | 高 | 覆盖无网络、慢网络、空数据、鉴权失败、并发、大列表分页、键盘弹起遮挡、权限拒绝 | 只跑开心路径、网络异常白屏、空数据显示"undefined"、无错误提示 |
| RD-3 | **Firebase 成本与性能** | 中 | Firestore 查询有索引（firestore.indexes.json）、避免 N+1、合理分页（limit）、图片用 CDN 缩略图、Functions 冷启动优化、onSnapshot 及时释放 | 全表扫描、onSnapshot 无限监听、图片加载原图、无分页 |
| RD-4 | **测试覆盖与可维护性** | 中 | Repository/Model 有单测、widget 测试覆盖关键组件、E2E 覆盖登录+发帖+浏览主流程、mock 只在边界 | 0 测试、测试耦合内部实现、mock 自己模块 |
| RD-5 | **可访问性与国际化** | 中 | Semantics 标签、字号可放大、色彩对比度 ≥4.5:1、文案抽成 key 便于 i18n | 按钮无语义、硬编码中文、图片无语义描述 |

### 校准锚点

- **RD-1 STRONG 示例**：PostCard 有加载骨架屏 + 空图 placeholder + 图片错误 fallback，所有颜色走 `AppColors`，间距走 `Spacing` token
- **RD-1 WEAK 示例**：PostCard 直接 `Color(0xFFFF0000)`、`SizedBox(height: 13.5)`、图片加载失败白屏
- **RD-2 STRONG 示例**：登录失败明确提示"手机号格式错误"或"验证码错误"，网络断开时有"重试"按钮
- **RD-2 WEAK 示例**：登录失败只 `print(e)`，无网络时 UI 卡住

## Harness 检查清单

Team-lead 在阶段边界检查：

- **文档 harness**：CLAUDE.md + 主 task_plan.md 还准确吗？
- **可观测性 harness**：progress.md 中的失败记录是否有足够细节？
- **不变量 harness**：Known Pitfalls 有条目应提升为自动化测试吗？
- **回放 harness**：本阶段是否产生了可复用的模式？

## Known Pitfalls

> 反复出现的失败模式追加到这里。

### KP-4: E2E `resetFirestore()` 对需要 where 条件的集合无效
- **症状 A**（J1 Strike 1）：未登录态调 `list posts` 被 firestore.rules L15 拒
- **症状 B**（J2 Strike 1）：即使登录态，`list applications/matches/reviews` 仍被拒（rules 要求 applicantId where 条件才能 list）
- **根因**：rules 设计为限制 list 操作防信息泄漏；任何客户端 SDK 的"清空集合"都要先 list，所以必然被拒
- **修复**：
  - 短期：发帖类测试用"唯一标题幂等"策略绕过 resetFirestore（J2 用的方案）
  - 长期 backlog：改走 Admin REST `DELETE http://127.0.0.1:8080/emulator/v1/projects/{p}/databases/(default)/documents/{col}` 绕 rules（emulator 专属接口），或把 test_fixtures.resetFirestore 重写为 Admin REST 版
- **预防**：J3-J4 派发时提醒；reviewer 审查 E2E 代码时标 [AUTOMATE]

### Backlog（UI 非阻塞）
- ~~**UI-BL-1** `post_card.dart:31:16` Column RenderFlex overflow 15px~~ — **已修复 2026-04-11**：根因在 `home_screen.dart` SliverGrid `mainAxisExtent: 290`（实际内容 ~306），改为 308，flow4.py 截图验证
- ~~**UI-BL-2** `home_screen.dart:64` 城市切换 InkWell `onTap: () {}` 是空实现~~ — **已修复 2026-04-11**：加 `_showCityPicker` bottom sheet（10 城市 + 打勾选中态），点 tap → show sheet → 选 city → `userRepositoryProvider.updateProfile({'city': picked})` → Firestore merge → currentAppUserProvider 响应式 rebuild home feed。CI PASS

### KP-6: firebase-admin `admin.firestore.FieldValue` 命名空间在 Functions emulator 里 undefined
- **症状**：applyToPost 事务内抛 `TypeError: Cannot read properties of undefined (reading 'serverTimestamp')`，指向 `admin.firestore.FieldValue.serverTimestamp()`
- **根因**：Node REPL 隔离测试里 `admin.firestore.FieldValue` 可正常访问；但 Functions emulator runtime 在 module load + 事务 callback 上下文里该静态命名空间变 undefined（可能与 `const db = admin.firestore();` 调用后 emulator proxy 有关）
- **修复**：改用 firebase-admin v12 模块化导入 `const { FieldValue, Timestamp } = require('firebase-admin/firestore');`，然后 `FieldValue.serverTimestamp()` / `Timestamp.fromDate(...)`
- **预防**：Functions 代码**禁**直接访问 `admin.firestore.FieldValue` / `admin.firestore.Timestamp`；2026-04-14 已在 applications/ai/deposits/notifications/antiGhosting 五个文件统一修复

### KP-7: firestore.rules 字段白名单与代码写入字段不一致（多处 prod bug）
- **症状**：4 处真实 prod bug，发现于 J2/J3 E2E 联调（2026-04-15）：
  1. `users` rules L12/L29 白名单仅 `age`，但 `app_router.dart:52` redirect 检查 `birthYear == null` 决定 onboarding 完成态 + `onboarding_screen.dart:89` 写 `birthYear` —— **任何用户都无法走完 onboarding**（rules 拒）
  2. `posts` rules L42-49 白名单缺 `minSlots`/`isInstant`/`expiresAt`，但 `post_create_repository.dart:146/156/161` 都写这些字段 —— **发布帖子永远 permission-denied**
  3. `config/categories` 集合无 rules entry，默认 deny → `categoriesProvider` Stream 报 permission-denied → 没有 fallback → **发帖页分类列表永远空**
  4. `create_post_screen.dart:49` 用 `ref.read(categoriesProvider).valueOrNull`（不订阅）→ Stream 后续 emit 不会触发 rebuild → **即使授权了 categories 也不显示**
- **修复**：
  - rules 加 `birthYear`/`minSlots`/`isInstant`/`expiresAt` 到对应 hasOnly 白名单
  - rules 加 `match /config/{docId} { allow read: if true; }`
  - `categoriesProvider` 加 `.handleError((Object _) => _defaults)` 流式兜底
  - `create_post_screen` 把 `ref.read` 改为 `ref.watch`
- **预防**：[AUTOMATE] golden_rules.py 增加"代码写入 collection.set/update 的字段集合 vs firestore.rules hasOnly 白名单"对比检查。任何 mismatch 即 fail
- **教训**：`hasOnly` 白名单很严格，多写一个字段就 deny 全部。代码改字段时**必须**同步 rules

### KP-5: dart-define flag 名拼写
- **症状**：phone OTP 不到 emulator，浏览器弹 reCAPTCHA 图片挑战
- **根因**：`main.dart:11` 用 `bool.fromEnvironment('USE_EMULATOR')`，但旧脚本/文档传 `--dart-define=USE_FIREBASE_EMULATOR=true` —— 名字不匹配，flag 永远 false，web SDK 走真 Firebase Auth
- **修复**：所有命令统一 `--dart-define=USE_EMULATOR=true`
- **预防**：派发任务前 grep `bool.fromEnvironment`/`String.fromEnvironment` 拿到唯一真相

### KP-2: Flutter web integration_test 不能用 `flutter test`
- **症状**：`flutter test -d chrome integration_test/...` 报 `Web devices are not supported for integration tests yet`
- **根因**：Flutter 官方决策，web integration_test 必须通过 flutter_driver
- **修复**：用 `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/journey_*.dart -d chrome`
- **前置**：启动 chromedriver（`C:\Users\CRISP\bin\chromedriver.exe --port=4444 &`）；`client/test_driver/integration_test.dart` 已就位
- **噪音**：setUpAll 阶段 `StateError: No element`（来自 `handlePointerEvent`/`firstWhere`）是 web binding 启动期无害噪音，不影响用例判定，忽略

### KP-3: Android AVD 在 C 盘告急时跑不起来
- **症状**：`flutter emulators --launch Pixel_7` 报 exit code 1，verbose 日志 `FATAL | Your device does not have enough disk space`
- **根因**：AVD 启动需要 6-8GB 可用，C 盘剩 1.41GB
- **修复**：阶段 3 改用 web+chrome 方案；长期需清 C 盘
- **预防**：E2E 默认走 web 路径

### KP-1: 派任务前不要假设代码路径
- **症状**：team-lead 在 task-storage-rules 中给的 Storage 路径（`users/{uid}/avatar`）与代码实际路径（`avatars/{uid}/...`）不符，dev 自己 grep 才发现
- **根因**：team-lead 凭直觉/惯例猜路径，未先 grep 验证
- **修复**：dev 应以代码为准，不盲信 task 描述
- **预防**：派任务时**只描述意图**，不写具体路径；让 dev 自己 grep 实际使用情况后回填到 task_plan.md

### Backlog（已识别但延后）
- WARN-2 (review-storage-rules)：storage.rules 单层 `{fileName}` 匹配——将来加多层路径会静默 deny
- AUTOMATE-1 (review-storage-rules)：补 `@firebase/rules-unit-testing` 4 个回归测试
- DEPLOY-1 (task-unify-region)：启用支付时，记得把微信/支付宝后台 webhook URL 改为 `asia-southeast1-<project>.cloudfunctions.net/depositPaymentCallback`
- DEPLOY-2 (task-unify-region)：首次部署 Functions 时，部署后 **< 2 分钟内**必须删除 asia-east1 老实例以避免触发器双跑（reviewer 收紧为 2min，因 deposits 触发器双跑可能资金错账）。完整 `functions:delete` 命令在 `.plans/dazi-app/reviewer/review-unify-region/findings.md` 部署 checklist 中

## 风格决策

> 用户品味偏好。3+ 次 → custodian 编码到 golden_rules.py。

| # | 决策 | 来源 | 状态 |
|---|------|------|------|
| SD-1 | Riverpod 仅用 `Provider` + `StreamProvider[.family]`；**禁** Notifier/StateNotifier/ChangeNotifier；UI 本地状态用 `setState` | T1e | active |
| SD-2 | Firebase SDK 必须通过 `firebaseXxxProvider` 构造注入，**禁** `FirebaseXxx.instance` 直接调用（`*_repository.dart` 中作为 Provider 工厂封装除外）| T1e | active |
| SD-3 | 异步加载统一用 `AsyncValue<T>` + `.when`，**禁**自定义 `{isLoading, error, data}` 三件套 | T1e | active |
| SD-4 | MVP 阶段不引入 `freezed` / `riverpod_generator` | T1e | active |
| SD-5 | **Glass Morph 主题系统**：所有颜色走 `GlassTheme.of(context).colors.*`（**禁** 硬编码 `Color(0xFF...)` 或直接用 `AppColors.*`，后者已 `@Deprecated`）；间距走 `Spacing.*`、圆角走 `Radii.*`；卡片/模态/输入框使用 `GlassCard`/`GlassButton`/`GlassInput`/`PillTag` 等通用组件；**透明度必须用** `color.withValues(alpha: x)`（Flutter 3.27+），**禁** `withOpacity`；Widget 测试中 `GlassTheme` 必须**包在 MaterialApp 外层**（否则 BottomSheet/PopupMenu 等 overlay 子树拿不到 GlassTheme） | Glass Morph UI 升级 2026-04-12 | active |

## 核心协议

| 协议 | 触发时机 | 操作 |
|------|---------|------|
| 需求对齐 | 团队搭建后、开发前 | researcher 盘点现有代码（T0a），team-lead 与用户对齐 MVP 范围（T0b） |
| 计划压力测试 | 架构定稿前 | 委托 researcher 走查每个决策分支 |
| 3-Strike 上报 | 智能体报告 3 次失败 | 读其 progress.md，给新方向或重新分配 |
| 代码审查 | 大功能/新模块完成 | dev 在 findings.md 写摘要，发给 reviewer |
| 阶段推进 | 阶段完成 | 调研完：读 findings 更新主计划；开发完：等 reviewer [OK]/[WARN] |
| CI 门禁 | 任何代码变更 | 运行 `python scripts/run_ci.py`，PASS 后才能提交审查 |
| 护栏捕获 | 3-Strike 解决后，或 reviewer [BLOCK] 修复后 | 会复现？→ Known Pitfalls；通用？→ [TEAM-PROTOCOL] |
| custodian 巡检 | 2-3 个 dev 任务完成后，或阶段边界 | team-lead 触发合规巡检 |
| 模式→自动化 | reviewer 标记 [AUTOMATE] | team-lead 转给 custodian 构建检查脚本 |
| 品味捕获 | 用户对代码风格表达偏好 | 记录到风格决策；3+ 次 → Pending automation |

## 文件结构

```
dazi-app/
  CLAUDE.md                       ← 本文件（始终加载）
  client/                         ← Flutter 客户端源码
  functions/                      ← Firebase Functions 源码
  public/                         ← 静态 HTML（post.html 等）
  scripts/
    golden_rules.py               ← 5 项通用检查
    run_ci.py                     ← CI 入口
  .plans/dazi-app/
    task_plan.md                  ← 主计划导航图
    findings.md / progress.md / decisions.md
    team-snapshot.md              ← 恢复用的缓存 prompts
    docs/
      index.md / architecture.md / api-contracts.md / invariants.md
    backend-dev/ frontend-dev/ researcher/ e2e-tester/ reviewer/ custodian/
      task_plan.md / findings.md / progress.md
      <前缀>-<任务>/               ← 任务文件夹
```
