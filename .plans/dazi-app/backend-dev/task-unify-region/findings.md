# task-unify-region Findings

## 背景
custodian 在 audit-doc-rewrite 发现：`firebase.json` 声明 `asia-southeast1`，`algoliaSync.js` v2 也在 `asia-southeast1`，但 5 个 v1 模块硬编码 `asia-east1`，导致 Flutter 客户端（若按 firebase.json 默认读 region）调 v1 callable 会 404。客户端 `application_repository.dart` 甚至定义了常量 `_functionsRegion = 'asia-east1'` 硬连到 `instanceFor`，与 firebase.json 又一次不一致。这是 MVP 上线前必修的 P0 阻断问题。

## 修改前完整调用点清单

### functions/src/ （21 处 .region('asia-east1')）

| 文件 | 行号 | 函数 |
|------|------|------|
| functions/src/notifications.js | 37 | registerFcmToken |
| functions/src/notifications.js | 50 | onNewApplication |
| functions/src/notifications.js | 74 | onApplicationStatusChange |
| functions/src/notifications.js | 113 | sendPreMeetingReminder |
| functions/src/notifications.js | 148 | onMonthlyReportGenerated |
| functions/src/ai.js | 32 | parseVoicePost |
| functions/src/ai.js | 80 | generateDescription |
| functions/src/ai.js | 112 | generateIcebreakers |
| functions/src/ai.js | 175 | generateRecapCard |
| functions/src/ai.js | 235 | generateMonthlyReports |
| functions/src/deposits.js | 22 | freezeDeposit |
| functions/src/deposits.js | 97 | depositPaymentCallback |
| functions/src/deposits.js | 126 | refundDeposit |
| functions/src/applications.js | 15 | applyToPost |
| functions/src/applications.js | 98 | acceptApplication |
| functions/src/applications.js | 182 | rejectApplication |
| functions/src/applications.js | 207 | expireApplications |
| functions/src/applications.js | 230 | submitReview |
| functions/src/antiGhosting.js | 22 | openCheckinWindow |
| functions/src/antiGhosting.js | 66 | submitCheckin |
| functions/src/antiGhosting.js | 127 | onCheckinTimeout |

### client/lib/ （1 处运行时常量 + 2 处注释）

| 文件 | 行号 | 类型 |
|------|------|------|
| client/lib/data/repositories/application_repository.dart | 9 | 运行时常量 const _functionsRegion = 'asia-east1';（被 FirebaseFunctions.instanceFor(region:) 使用，真正会导致 404） |
| client/lib/data/repositories/checkin_repository.dart | 10 | Dartdoc 注释 |
| client/lib/data/repositories/review_repository.dart | 10 | Dartdoc 注释 |

说明：checkin_repository 和 review_repository 没有独立 provider，它们从 application_repository.dart 导入了 firebaseFunctionsProvider，所以三者共享同一个 region 常量，只需改一处运行时就能同时修复三者。但注释仍会误导维护者，一并修正。

## 每个点的修改描述

- 所有 functions/src/ 中 21 处 .region('asia-east1') -> .region('asia-southeast1')（逐文件 Edit，replace_all=true）
- application_repository.dart:9 const _functionsRegion = 'asia-east1'; -> 'asia-southeast1';
- checkin_repository.dart:10 注释中的区域名更新
- review_repository.dart:10 注释中的区域名更新

## 验证结果

修改后在整个 dazi-app 目录执行 Grep asia-east1，源代码（functions/src/、client/lib/、public/）0 匹配。剩余 22 条匹配全部集中在 .plans/dazi-app/（task_plan.md、docs/api-contracts.md、docs/architecture.md、custodian/audit-doc-rewrite/findings.md），都属于文档/计划的历史引用。

## 客户端是否需要配套修改

需要，且已修改。客户端不只是注释问题——application_repository.dart 真的用 FirebaseFunctions.instanceFor(region: 'asia-east1') 在运行时指定了错误的 region。这意味着即使只改后端、只改 firebase.json，客户端仍会按 asia-east1 发请求。本任务把常量改到 asia-southeast1，客户端/后端/firebase.json 三者已全部一致。

## docs/ 更新建议（标注给 custodian）

以下文档仍引用 asia-east1，不在本任务范围内，请 custodian 在下次巡检中同步更新：

1. .plans/dazi-app/docs/architecture.md
   - Line 43：（Node 22，部分 asia-east1，部分 asia-southeast1）-> 统一为 asia-southeast1
   - Line 56：区域配置表格中整行关于 v1 函数在 asia-east1 的描述，应改为 asia-southeast1，并可删除"部分/部分"的区分
2. .plans/dazi-app/docs/api-contracts.md Line 222-266：所有 18 个函数的 region 标注统一更新为 asia-southeast1
3. .plans/dazi-app/task_plan.md Line 62：T1b 任务描述已反映目标，可标为完成
4. .plans/dazi-app/custodian/audit-doc-rewrite/findings.md：作为审计历史记录保留原文即可，无需改动

## 部署前注意事项

这是 P0 注意事项——部署时会产生副作用，不仅仅是代码变更。

1. v1 函数 region 变更不会迁移实例，会创建新实例
   Firebase Functions v1 将 region 视为函数身份的一部分。把 parseVoicePost 从 asia-east1 改到 asia-southeast1 后执行 firebase deploy --only functions：
   - 会在 asia-southeast1 创建一个新的 parseVoicePost
   - asia-east1 的老 parseVoicePost 不会被自动删除，会继续占用配额、继续被旧客户端调用
   - 必须手动删除旧实例：firebase functions:delete parseVoicePost --region asia-east1 --force

2. 批量删除命令（建议部署后立即执行）
   firebase functions:delete \
     registerFcmToken onNewApplication onApplicationStatusChange sendPreMeetingReminder onMonthlyReportGenerated \
     parseVoicePost generateDescription generateIcebreakers generateRecapCard generateMonthlyReports \
     freezeDeposit depositPaymentCallback refundDeposit \
     applyToPost acceptApplication rejectApplication expireApplications submitReview \
     openCheckinWindow submitCheckin onCheckinTimeout \
     --region asia-east1 --force

3. Firestore 触发器（onCreate/onUpdate）需要特别注意
   onNewApplication、onApplicationStatusChange、onMonthlyReportGenerated 是 Firestore 触发器。两个 region 同时存在时，对同一个文档的写入会触发两份触发器（新老都跑），可能产生重复推送/重复写入。必须在部署新版本后立即删除老实例。推荐：部署后 5 分钟内执行删除命令。

4. Pub/Sub 定时任务
   sendPreMeetingReminder、generateMonthlyReports、expireApplications、openCheckinWindow、onCheckinTimeout 是 scheduled 函数，两个 region 并存期间定时任务会跑两次——会产生重复处理。同样要求部署后立即删除老实例。

5. HTTP webhook 回调 URL 会变更
   depositPaymentCallback 是 onRequest，URL 从 https://asia-east1-<project>.cloudfunctions.net/depositPaymentCallback 变为 https://asia-southeast1-<project>.cloudfunctions.net/depositPaymentCallback。必须同步更新微信支付/支付宝的 webhook 配置，否则押金回调会失败。部署 checklist 必须包含这一步。

6. 客户端发版节奏
   客户端 _functionsRegion 也已更新。如果已有老版本客户端在线上（asia-east1 版），删除老函数后老客户端会全面崩溃。部署顺序建议：
   - a) 后端先部署新版本到 asia-southeast1（老实例保留）
   - b) 发布新客户端并确保用户升级（或强制升级）
   - c) 等老客户端占比低于阈值后再删除 asia-east1 老实例
   - 若是 MVP 未发版，可直接部署 + 立刻删除老实例，无需灰度。

## 风险评估
- 修改本身风险低（只是字符串替换，不涉及业务逻辑）
- 部署风险中（见上文 1-5 条，尤其是 Firestore 触发器重复执行和 webhook URL 变更）

## 审查请求
[REVIEW-REQUEST] 需要 reviewer 确认修改覆盖完整
