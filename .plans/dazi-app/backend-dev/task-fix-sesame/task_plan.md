# task-fix-sesame

## 范围
修复 `functions/src/deposits.js:47` 中对 `user.sesameScore` 的字段引用不一致问题。AppUser 客户端模型只声明了 `sesameAuthorized` (bool)，没有 `sesameScore`，导致该条件分支永远无法命中。

## 验收标准
- deposits.js 不再读取未定义字段 `sesameScore`
- 保留 `sesameAuthorized` 的判断语义
- 客户端 `app_user.dart` 不做改动（MVP 走 D3 信用承诺，不需要芝麻分）
- 不重构 deposits.js 其它业务逻辑

## 交付物
- `functions/src/deposits.js` 2 行以内改动
- `findings.md` 调查结论 + diff
- `progress.md` 进度记录

## 审查
小改动，自述即可，不走 reviewer。
