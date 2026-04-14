# M-8 Functions v1→v2 迁移评估

**日期**: 2026-04-14
**作者**: team-lead（backend-dev 代行）
**状态**: 评估完成（未执行）
**输入**: reviewer T1 verdict backlog M-8
**输出**: 本文件 + 推荐决策

---

## 1. 现状盘点

### 1.1 依赖
- `firebase-functions: ^4.9.0`（同时支持 v1/v2 API，无需升级 SDK）
- `node: 22`（v2 最低要求 Node 20，已满足）
- 区域：全部显式 `asia-southeast1`（KP DEPLOY-2 已记录区域迁移敏感性）

### 1.2 触发器清单（按 API 版本分组）

#### v2 已迁移（2 个，[algoliaSync.js](functions/src/algoliaSync.js)）
| export | 类型 | 说明 |
|--------|------|------|
| `syncPostToAlgolia` | `onDocumentWritten` | posts 写入 → Algolia 同步 |
| `algoliaBackfill` | `onRequest` | 一次性 backfill HTTP endpoint |

**意义**：团队已掌握 v2 API，且 v2 和 v1 可在同一项目共存。

#### v1 待迁移（21 个）

| 文件 | export | 类型 | v2 对应 |
|------|--------|------|---------|
| [ai.js](functions/src/ai.js) | `parseVoicePost` | `https.onCall` | `onCall` |
| ai.js | `generateDescription` | `https.onCall` | `onCall` |
| ai.js | `generateIcebreakers` | `https.onCall` | `onCall` |
| ai.js | `generateRecapCard` | `https.onCall` | `onCall` |
| ai.js | `generateMonthlyReports` | `pubsub.schedule` | `onSchedule` |
| [antiGhosting.js](functions/src/antiGhosting.js) | `openCheckinWindow` | `pubsub.schedule` | `onSchedule` |
| antiGhosting.js | `submitCheckin` | `https.onCall` | `onCall` |
| antiGhosting.js | `onCheckinTimeout` | `pubsub.schedule` | `onSchedule` |
| [applications.js](functions/src/applications.js) | `applyToPost` | `https.onCall` | `onCall` |
| applications.js | `acceptApplication` | `https.onCall` | `onCall` |
| applications.js | `rejectApplication` | `https.onCall` | `onCall` |
| applications.js | `withdrawApplication` | `https.onCall` | `onCall` |
| applications.js | `expireApplications` | `pubsub.schedule` | `onSchedule` |
| applications.js | `submitReview` | `https.onCall` | `onCall` |
| [deposits.js](functions/src/deposits.js) | `freezeDeposit` | `https.onCall` | `onCall` |
| deposits.js | `depositPaymentCallback` | `https.onRequest` | `onRequest` |
| deposits.js | `refundDeposit` | `https.onCall` | `onCall` |
| [notifications.js](functions/src/notifications.js) | `registerFcmToken` | `https.onCall` | `onCall` |
| notifications.js | `onNewApplication` | `firestore.document.onCreate` | `onDocumentCreated` |
| notifications.js | `onApplicationStatusChange` | `firestore.document.onUpdate` | `onDocumentUpdated` |
| notifications.js | `sendPreMeetingReminder` | `pubsub.schedule` | `onSchedule` |
| notifications.js | `onMonthlyReportGenerated` | `firestore.document.onCreate` | `onDocumentCreated` |

**按类型汇总**：
- onCall: **13**
- onRequest: **1**
- onSchedule: **5**
- firestore trigger: **3**

---

## 2. 迁移收益

| 维度 | v1 | v2 | 收益 |
|------|----|----|------|
| 并发模型 | 单实例=单请求 | `concurrency: 80`（默认） | 高负载下实例数 ↓ ~80×，账单 ↓ |
| 冷启动 | 较慢 | 基于 Cloud Run，优化后更快 | 首请求延迟 ↓ |
| 每函数配置 | 必须 `.region().runWith()` 链式 | 声明式 options 对象 + `setGlobalOptions` | 可读性、一致性 ↑ |
| 新特性 | ❌ | App Check、eventarc、CPU 可配、VPC egress 设置 | 安全/性能扩展性 |
| 官方立场 | 维护模式（仍受支持） | 推荐用于新项目 | 长期可维护 |

**实际对本项目影响**：
- **openCheckinWindow / onCheckinTimeout / expireApplications / sendPreMeetingReminder**（每 5-10 分钟全表扫描）是冷启动敏感 —— v2 concurrency 受益最明显。
- **onCall 矩阵**（13 个）在促销高峰期可能同时被多用户调用 —— v2 并发节省实例。
- **Firestore 触发器**（3 个）流量小，收益有限。

---

## 3. 破坏性变更 checklist

### 3.1 `onCall`（13 个）
```diff
- const functions = require('firebase-functions');
+ const { onCall, HttpsError } = require('firebase-functions/v2/https');

- exports.applyToPost = functions
-   .region('asia-southeast1')
-   .https.onCall(async (data, context) => {
-     if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');
-     const uid = context.auth.uid;
-     const { postId } = data;
+ exports.applyToPost = onCall(
+   { region: 'asia-southeast1' },
+   async (request) => {
+     if (!request.auth) throw new HttpsError('unauthenticated', '请先登录');
+     const uid = request.auth.uid;
+     const { postId } = request.data;
```

- `data, context` → `request`（单对象）
- `context.auth` → `request.auth`
- `data` → `request.data`
- `HttpsError` 改从 `/v2/https` 导入
- `rawRequest` 改为 `request.rawRequest`

**改动点**：每个 onCall 约 5-10 行改动。客户端 Flutter SDK 无需变更（callable 通过函数名解析，不看版本）。

### 3.2 `onRequest`（1 个 — `depositPaymentCallback`）
```diff
- const { onRequest } = require('firebase-functions/v2/https');
- exports.depositPaymentCallback = functions
-   .region('asia-southeast1')
-   .https.onRequest(async (req, res) => { ... });
+ exports.depositPaymentCallback = onRequest(
+   { region: 'asia-southeast1' },
+   async (req, res) => { ... }
+ );
```

- req/res 签名不变
- **HMAC 签名验证逻辑无影响**（body parsing 仍然是 `req.rawBody`）
- **关键风险**：v2 HTTP 函数 URL 格式变化！`asia-southeast1-<project>.cloudfunctions.net/depositPaymentCallback` → `depositPaymentCallback-<hash>-<region>.a.run.app`
  - **必须**：在微信/支付宝后台更新 webhook URL
  - **缓解**：先在 `firebase.json` 加 `hosting.rewrites` 保持旧 URL 可达；OR 用 custom domain

### 3.3 `onSchedule`（5 个）
```diff
- exports.openCheckinWindow = functions
-   .region('asia-southeast1')
-   .pubsub.schedule('every 5 minutes')
-   .onRun(async () => { ... });
+ const { onSchedule } = require('firebase-functions/v2/scheduler');
+ exports.openCheckinWindow = onSchedule(
+   { schedule: 'every 5 minutes', region: 'asia-southeast1', timeZone: 'Asia/Shanghai' },
+   async (event) => { ... }
+ );
```

- cron 字符串格式兼容
- handler 签名：`() => {}` → `(event) => {}`（参数少用，低风险）
- **时区**：v1 默认 UTC，v2 必须显式指定 —— **必须加 `timeZone: 'Asia/Shanghai'`** 否则 `generateMonthlyReports` 的"月初"会偏 8 小时
- **历史作业续跑**：v2 onSchedule 创建新的 Cloud Scheduler job（新名字），v1 旧 job 需手动在 console 或 gcloud 删除

### 3.4 Firestore 触发器（3 个）—— **最大破坏点**

```diff
- exports.onNewApplication = functions
-   .region('asia-southeast1')
-   .firestore.document('applications/{applicationId}')
-   .onCreate(async (snap, context) => {
-     const app = snap.data();
-     const { applicationId } = context.params;
+ const { onDocumentCreated } = require('firebase-functions/v2/firestore');
+ exports.onNewApplication = onDocumentCreated(
+   { document: 'applications/{applicationId}', region: 'asia-southeast1' },
+   async (event) => {
+     const app = event.data?.data();
+     const { applicationId } = event.params;
```

- `snap` → `event.data`
- `context.params` → `event.params`
- onUpdate 的 `change.before/after` → `event.data.before/after`
- **v1 和 v2 Firestore 触发器不会自动互斥** → 同名函数也会双触发（v1 在 functions.cloudfunctions.net，v2 在 eventarc）

---

## 4. 部署风险分析

### 4.1 双触发窗口（最高风险）
Firebase CLI 检测到 v1→v2 迁移时**不会**自动替换，而是**视为删 v1 + 新建 v2**。部署瞬间：
- 如果先删 v1 再建 v2 → 有停机窗口（对 payment callback 致命）
- 如果先建 v2 再删 v1 → **双触发窗口**：

| 触发类型 | 双触发后果 |
|---------|----------|
| `onCall` | 客户端只看函数名解析，不会同时调两次 —— **安全** |
| `onRequest` | 两个函数共存于不同 URL，payment callback 需切换 webhook —— **可控** |
| `onSchedule` | 两个 Cloud Scheduler job 同时触发 —— **会跑两遍**（openCheckinWindow 无害，generateMonthlyReports 会重复扣费 Claude API）|
| Firestore 触发 | 同一 Firestore 事件被两个函数同时接收 —— **onNewApplication 会发两次推送**、**onMonthlyReportGenerated 可能双重通知** |

### 4.2 缓解措施

**策略 A：重命名法（推荐）**
1. v2 函数用新名字：`applyToPost` → `applyToPostV2`
2. 部署后先切客户端/webhook 到新名字
3. 观察 24h 无异常
4. 删除 v1 旧函数
5. （可选）一段时间后把 v2 改回原名再次迁移

**弊端**：客户端代码改动、两次部署

**策略 B：带旗标的停机切换**
1. 所有 schedule/firestore 触发在代码里加 feature flag：`if (process.env.DISABLE_V1_TRIGGERS === 'true') return;`
2. 部署 v1 旗标开启版本 → v1 静默
3. 部署 v2 函数
4. 验证 v2 → 删除 v1

**弊端**：需要 env var 协调；onCall 不适用

**策略 C：按触发类型分批**
- 第 1 批：**onCall**（13 个）—— 无双触发风险，可直接 in-place 替换
- 第 2 批：**onRequest** —— 单个 `depositPaymentCallback`，切换 webhook 是已知流程（KP DEPLOY-1）
- 第 3 批：**onSchedule**（5 个）—— 用策略 A 重命名
- 第 4 批：**firestore trigger**（3 个）—— 用策略 A 重命名，最谨慎

---

## 5. 工作量估算

| 阶段 | 内容 | 人天 |
|------|------|------|
| P0 迁移准备 | setGlobalOptions + 封装 region 常量 + 更新 Jest mock | 0.5 |
| P1 onCall（13） | 代码改写 + 测试调整 | 1.0 |
| P2 onRequest（1） | depositPaymentCallback 改写 + 微信/支付宝 webhook 切换 | 0.5 |
| P3 onSchedule（5） | 改写 + 重命名 + Cloud Scheduler 清理 | 1.0 |
| P4 firestore（3） | 改写 + 重命名 + 双触发窗口观察 | 1.0 |
| P5 观察与清理 | 删除 v1、监控 Cloud Logging | 0.5 |
| **合计** | | **4.5 dev-days** |

**前提**：Jest 单测基线已有（T1 已建），每个函数至少有 1 条回归测试。

---

## 6. 推荐决策

### 不建议立即执行

**理由**：
1. **收益窗口未到** —— 当前 DAU 未知/小，concurrency 节省几乎看不见（v1 实例也没打满）
2. **风险窗口开着** —— payment callback webhook 切换、schedule 双跑生成 Claude 账单、firestore 双推送 —— 任一出问题直接用户可感知
3. **机会成本** —— 4.5 dev-days 可以优先投 RD-5（i18n/a11y）或 T3 E2E，后两者是 WEAK/缺失，v1→v2 是 ADEQUATE→BETTER
4. **v1 仍受支持** —— firebase-functions 4.x 继续维护 v1 API 至少到 2026 年底（参考官方迁移指南）

### 建议时机
- **触发条件**：出现以下任一情况时立即启动
  - Functions 月账单 > $50 且实例数 / 请求数比 > 1:10（concurrency 收益显现）
  - 出现冷启动导致的用户可感知延迟投诉
  - firebase-functions 5.x 发布并宣布 v1 废弃时间表
- **执行前置**：
  - KP DEPLOY-2（区域迁移）必须已完成（避免 v1→v2 + region 双迁移叠加）
  - T3 E2E 必须已覆盖 payment callback + onSchedule 路径（提供回归基线）

### 如果现在必须做一部分
**只做 P1（onCall 13 个）**：
- 零双触发风险
- 零 webhook 切换
- 1 个 dev-day 可完成
- 可作为团队熟悉 v2 的练习
- **不做 schedule + firestore + onRequest** —— 这三类才是真正的坑

---

## 7. 参考资料

- `functions/src/algoliaSync.js` —— 团队现成的 v2 参考实现
- Firebase 官方 v2 upgrade guide: https://firebase.google.com/docs/functions/2nd-gen-upgrade
- `.plans/dazi-app/CLAUDE.md` KP DEPLOY-2 区域迁移笔记
- 本任务未改代码；如执行，建议拆成独立 task `task-v2-migration-p1/`（仅 onCall）

---

## 8. 结论

**判决**：M-8 标记为 **DEFERRED**，本评估产出即为结案交付物。
- **不执行**的依据：RISK > BENEFIT at current scale
- **触发重新评估**的条件：见第 6 节"建议时机"
- **若用户坚持推进**：建议仅做 P1（onCall），预留 1 dev-day
