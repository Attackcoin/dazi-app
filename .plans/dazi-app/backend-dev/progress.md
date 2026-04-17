# backend-dev - 工作日志

> 用于上下文恢复。压缩/重启后先读此文件。

---

## 2026-04-12 - T2 安全修复（task-security-fixes）

**状态：全部完成，等待 reviewer 复审**

修复了 reviewer [BLOCK] 审查报告中的 9 个问题：

| ID | 文件 | 问题 | 状态 |
|----|------|------|------|
| C-1 | firestore.rules:9 | users write 无字段白名单 | 完成 |
| C-2 | deposits.js:99-104 | 支付回调签名被注释 | 完成 |
| H-2 | firestore.rules:16-17 | posts create/update 无白名单 | 完成 |
| H-3 | firestore.indexes.json | 缺 9 个复合索引 | 完成 |
| H-5 | applications.js:278 | submitReview 全量查询 race condition | 完成 |
| H-6 | notifications.js:56-58 | postDoc.exists 未检查 | 完成 |
| H-7 | ai.js | AI 接口无输入长度限制 | 完成 |
| M-7 | firestore.rules reviews | 无防重复保护 | 完成 |
| M-8 | antiGhosting.js | openCheckinWindow 每分钟扫全表 | 完成 |

**下一步：请 reviewer 复审这批修改**

## 2026-04-16 - T5-03 活动后轻量反馈系统

**状态：完成（小任务，无需审查）**

实现 Hinge "We Met?" 式二选一快速反馈，用作匹配算法训练信号。

### 交付物

| 文件 | 变更 |
|------|------|
| `functions/src/antiGhosting.js` | 新增 `submitQuickFeedback` onCall Function + `_sendQuickFeedbackNotification` 推送 |
| `functions/__tests__/antiGhosting.test.js` | 新增 10 条测试（正/反双向覆盖） |
| `client/lib/data/models/match.dart` | `AppMatch` 加 `quickFeedback` Map 字段 + 解析 + 查询辅助方法 |
| `.plans/dazi-app/docs/api-contracts.md` | 新增 `submitQuickFeedback` API 文档 |

### 设计决策

- **选择 onCall Function 而非客户端直写**：更安全（参与者身份校验 + 值枚举验证），且与项目现有模式（submitCheckin/submitReview）一致。quickFeedback 通过 Admin SDK 写入，不需要修改 firestore.rules
- **触发时机**：match completed（submitCheckin 全员签到后）+ checkin timeout（onCheckinTimeout 超时后）均推送 quick_feedback 通知
- **数据模型**：`quickFeedback` 为 map 字段 `{ uid1: "met"|"no_show", uid2: "met"|"no_show" }`，用点路径写入保证各参与者互不覆盖

### 测试结果

- Functions: 41/41 PASS（含 10 条新测试）
- `flutter analyze match.dart`: 0 issues

## 2026-04-17 - T5-01 身份验证系统（task-identity-verification）

**状态：完成**

实现 Stripe Identity 身份验证后端，支持用户证件验证（verificationLevel 1→2）。

### 交付物

| 文件 | 变更 |
|------|------|
| `functions/src/identity.js` | 新增 `startIdentityVerification` onCall + `stripeIdentityWebhook` onRequest |
| `functions/src/index.js` | 导出 identity 模块 |
| `functions/__tests__/identity.test.js` | 新增 6 条测试 |
| `functions/package.json` | 新增 `stripe` 依赖 |
| `.plans/dazi-app/docs/api-contracts.md` | 新增两个 API 文档 |

### 测试结果

- Functions: 47/47 PASS（含 6 条新测试）
