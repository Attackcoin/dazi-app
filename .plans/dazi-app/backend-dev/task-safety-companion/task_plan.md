# T5-12 AI 安全伴侣 — 后端部分

## 目标
为线下搭子活动提供安全保障机制：未签到用户的安全确认流程 + 超时升级通知。

## 验收标准
1. [x] `npm test` 全部通过（72/72）
2. [x] firestore.rules 已更新（safetyAlerts 集合）
3. [x] `confirmSafety` 可正常确认安全
4. [x] `onCheckinTimeout` 会为未签到用户创建 safetyAlert
5. [x] api-contracts.md 已更新

## 变更清单

### 新文件
- `functions/src/safety.js` — 安全伴侣模块（confirmSafety + escalateSafetyAlert + _createSafetyAlert）
- `functions/__tests__/safety.test.js` — 14 个测试用例

### 修改文件
- `functions/src/antiGhosting.js` — onCheckinTimeout 增加安全提醒创建（import + 调用 _createSafetyAlert）
- `functions/src/index.js` — 导出 safety 模块
- `firestore.rules` — 新增 safetyAlerts 集合规则
- `functions/__tests__/setup.js` — Timestamp mock 添加 valueOf() 支持比较运算
- `.plans/dazi-app/docs/api-contracts.md` — 新增 confirmSafety + escalateSafetyAlert 契约

## 设计决策
- safety.js 独立模块（而非塞入 antiGhosting.js），职责分离更清晰
- _createSafetyAlert 为内部函数，由 antiGhosting 可信路径调用，不暴露为 onCall
- 幂等设计：alertId = `${matchId}_${uid}`，重复调用不会创建重复记录
- MVP 阶段 escalate 只记日志 + 推送，不发实际短信/邮件
- Timestamp mock 需要 valueOf() 才能让 FakeQuery 的 <= 比较正确工作
