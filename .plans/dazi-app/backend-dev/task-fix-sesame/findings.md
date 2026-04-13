# task-fix-sesame - 调查结论

## 背景
custodian 在 audit-doc-rewrite 中发现 functions/src/deposits.js:47 读取 user.sesameScore，但客户端 AppUser 模型只声明了 sesameAuthorized（bool），没有 sesameScore 字段。

## 调查发现
1. 全仓 grep sesameScore：functions/src/deposits.js:47 是唯一代码读取点，其余都是文档。没有任何地方写入 sesameScore（auth_repository.dart:108 创建用户时只写 sesameAuthorized: false）。
2. 全仓 grep sesameAuthorized：app_user.dart:18,43,78,111 声明 + fromFirestore + toCreateMap；auth_repository.dart:108 注册写 false；deposits.js:47 读取。设计文档 design-document.md:224 明确只有 bool sesameAuthorized。
3. deposits.js 原逻辑：`if (user.sesameAuthorized && user.sesameScore >= 750)`。因 sesameScore 在所有写入路径均不存在，undefined >= 750 恒 false，分支永远无法命中——即便用户授权芝麻信用也会被迫走支付。这是隐蔽 bug，但 MVP 下 deposits.js 整体是 D3 的 dead code，无活路径影响。
4. MVP 上下文：主 task_plan 已走 D3 信用承诺方案，freezeDeposit/refundDeposit/depositPaymentCallback 三个 Callable 客户端根本不调用。

## 方案选择
- **方案 A（采纳）**：删除 sesameScore 读取，保留 sesameAuthorized 条件判断
- 方案 B：在 AppUser 补 sesameScore 字段 — 否决，MVP 不接入评分且设计文档也没这个字段
- 方案 C：typo bug — 等价于方案 A

选 A 理由：(1) 与客户端 AppUser 模型对齐；(2) 修复原条件永为 false 的隐蔽 bug；(3) MVP 不走该路径，零风险；(4) 改动 1 行代码 + 3 行注释，最小化。

## 改动 Diff
```
-    if (user.sesameAuthorized && user.sesameScore >= 750) {
+    // 注：AppUser 模型只有 sesameAuthorized (bool)，没有 sesameScore 字段。
+    // 原逻辑 sesameAuthorized && sesameScore >= 750 永为 false（sesameScore 恒 undefined）。
+    // D3 信用承诺 MVP 下本函数为 dead code，此处仅修复字段不一致 bug。
+    if (user.sesameAuthorized) {
```

## 自述审查（代替 reviewer）
- 正确性：语义与客户端字段对齐，不会引入新的 undefined 读取
- 安全性：未放宽权限，未改变 deposits 集合写入模式
- 影响面：deposits.js 在 D3 MVP 下是 dead code，改动不影响任何活路径
- 向后兼容：将来真接入芝麻分时，在 AppUser 补 sesameScore 字段并恢复阈值判断即可，注释已提示
- 文档同步：.plans/dazi-app/docs/api-contracts.md:35 仍提到 sesameScore 字段，建议 custodian 下一轮 doc 巡检时移除（本任务范围内不改，避免越权）

## 状态
complete
