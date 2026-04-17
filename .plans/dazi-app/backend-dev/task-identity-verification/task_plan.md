# T5-01 身份验证系统 -- 后端部分

> 状态: 完成
> 分配: backend-dev
> 创建: 2026-04-17

## 目标

实现 Stripe Identity 身份验证的后端 Cloud Functions，为用户提供证件验证能力（verificationLevel 2）。

## 验收标准

1. `npm test` 全部通过（含 6 条新测试）
2. `startIdentityVerification` onCall 返回 clientSecret
3. `stripeIdentityWebhook` onRequest 正确升级 verificationLevel
4. `api-contracts.md` 已更新

## 步骤

- [x] Step 1: 安装 Stripe SDK
- [x] Step 2: 创建 `functions/src/identity.js`（startIdentityVerification + stripeIdentityWebhook）
- [x] Step 3: 在 `functions/src/index.js` 导出
- [x] Step 4: Stripe 配置（env var null-check）
- [x] Step 5: 测试 `functions/__tests__/identity.test.js`（6 条）
- [x] Step 6: 更新 api-contracts.md

## 依赖

- Stripe SDK (`stripe` npm package)
- `users` 文档已有 `verificationLevel` 字段
- `verificationLevel`/`verifiedAt` 不在 firestore.rules 用户写白名单中（只由 Functions 写）
