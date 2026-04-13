# audit-doc-rewrite — 发现

> 任务：根据 researcher T0a 盘点重写 `docs/architecture.md` 与 `docs/api-contracts.md`，使其匹配真实代码。
> 执行：custodian
> 日期：2026-04-09
> 状态：complete

---

## 1. 做了什么

1. **完全重写** `.plans/dazi-app/docs/architecture.md`
   - 按真实代码描述产品为"搭子撮合 + 防爽约 + 担保交易 + AI 辅助"复合产品
   - 补全系统组件 ASCII 图（含 Flutter / Firebase Auth / Firestore / Functions 6 模块 / Algolia / Storage / FCM / Realtime DB / Claude Haiku）
   - 列出 Flutter 9 个 feature 模块、5 个 model、9 个 repository
   - 逐模块列出 6 个 Functions 模块的函数清单与触发类型
   - 画出 3 个核心业务流程（发帖→申请→匹配 / 签到与防爽约 / 评价与月报）
   - 填入真实技术栈版本（pubspec.yaml + functions/package.json 精确版本号）
   - 新增 §9 "D3 信用承诺模式影响清单" 明确 MVP 语义
2. **完全重写** `.plans/dazi-app/docs/api-contracts.md`
   - Firestore 8 个集合的全部字段（来源标注到 model 文件 + 行号）
   - 20+ Functions 接口清单（callable 入参/返回 / trigger 路径 / scheduled cron / 行号）
   - 5 个复合索引 + 对应覆盖查询
   - Storage 两条实际路径 `avatars/{uid}/...` 和 `posts/{uid}/...`（从代码 grep 得到）
   - Realtime DB `chats/{chatId}/messages` 字段
   - Algolia 索引字段映射与环境变量
   - 前端 16 条路由表
3. 更新 `docs/index.md`：
   - Section 导航对应新章节号
   - 审计日期 2026-04-09，状态从 `[NEW]` → `[REWRITTEN by custodian]`（architecture + api-contracts）
4. 根索引 `custodian/findings.md` 追加 audit-doc-rewrite 条目

---

## 2. 原文档 vs 真实代码 — 核心差异

| 维度 | 原 architecture.md 描述 | 真实代码 |
|------|-----------------------|---------|
| 产品类型 | "手机号登录、发帖、浏览信息流"的简单发帖 App | 线下撮合 + 防爽约 + 担保交易 + AI 辅助 |
| 模型数量 | 未列 | 5 个 model + 多个 sub-class（PostLocation / GenderQuota / GenderCount / RecapCard / MatchParticipant 等） |
| 后端模块 | 仅模糊提及 Firebase Functions | 6 个模块共 20+ 函数（含 trigger/scheduled/callable 三类） |
| 数据流 | 未画 | 3 个核心流程需 ASCII 描述 |
| 押金逻辑 | 未提 | D3 决策下的"信用承诺"特殊语义 |
| 多区域 | 未提 | asia-east1（大部分 v1 函数）与 asia-southeast1（firebase.json + v2 函数）不一致 |
| Realtime DB | 未提 | 聊天系统用 Firebase Realtime DB（`chats/{chatId}/messages`），Firestore 只存 match |
| Algolia | 未提 | 6 个模块中 1 个专门同步 posts 到 Algolia 索引 |

### 原 api-contracts.md 状态

- 只是初始骨架，实际无任何集合/接口定义。本次从代码提取全部字段填充。

---

## 3. 与 invariants.md / researcher findings 的比对

### 3.1 不一致点（已在 api-contracts §7 标注，未自动改 invariants）

- **函数数量**：researcher findings 估计"约 15 个 callable/trigger"。本次精确盘点总计 23 个（含内部 `_generateRecapCard`）：
  - ai.js 5（parseVoicePost · generateDescription · generateIcebreakers · generateRecapCard · generateMonthlyReports）
  - applications.js 5（applyToPost · acceptApplication · rejectApplication · expireApplications · submitReview）
  - antiGhosting.js 3（openCheckinWindow · submitCheckin · onCheckinTimeout）
  - deposits.js 3（freezeDeposit · depositPaymentCallback · refundDeposit）
  - notifications.js 5（registerFcmToken · onNewApplication · onApplicationStatusChange · sendPreMeetingReminder · onMonthlyReportGenerated）
  - algoliaSync.js 2（syncPostToAlgolia · algoliaBackfill）
- **区域不一致**：researcher 只提 asia-southeast1，实际 v1 函数写的是 asia-east1。建议 backend-dev 统一。
- **Storage Rules 状态**：researcher 标为"⚠缺失"，但仓库中已存在 storage.rules 且 invariants INV-2a 已标"已修复"。推测 researcher 调研时间早于 task-storage-rules 落地。本次文档按现状记录 ✅ 已存在。
- **reports 集合**：firestore.rules 里允许 create，但 functions/src 下无任何代码读写 —— 这是预留的"用户举报"写入入口，审核路径未实现。已在 api-contracts §1.8 标注。
- **sesameScore 字段**：deposits.js:47 会读取 user.sesameScore，但 app_user.dart 中没有此字段（只有 sesameAuthorized）。MVP 不会走这条路径，但仍是客户端模型/后端读取的不一致。

### 3.2 冲突但未自动改的项

按任务限制，未修改 invariants.md；上述差异留给 team-lead 决定是否提任务。

---

## 4. 未处理 / 后续建议

- invariants.md 应新增关于 Realtime DB 聊天消息读写隔离的不变量
- sesameScore 字段一致性问题应让 backend-dev 修复（要么删 deposits.js 的引用，要么往 AppUser 加字段）
- 区域不一致（asia-east1 vs asia-southeast1）应在下一次 backend-dev 任务中统一
- Functions 版本升级路径：v1 (firebase-functions@^4.9.0) 与 v2 API 混用，algoliaSync.js 已用 v2；其他模块未来可迁移

---

## 5. 交付物清单

| 文件 | 操作 |
|------|------|
| .plans/dazi-app/docs/architecture.md | 完全重写 |
| .plans/dazi-app/docs/api-contracts.md | 完全重写 |
| .plans/dazi-app/docs/index.md | Section 与状态更新 |
| .plans/dazi-app/custodian/audit-doc-rewrite/findings.md | 新建（本文件） |
| .plans/dazi-app/custodian/audit-doc-rewrite/progress.md | 新建 |
| .plans/dazi-app/custodian/findings.md | 根索引追加一条 |
