# task-unify-region 实施清单

## 目标
将所有 Firebase Functions v1 模块的部署区域从 `asia-east1` 统一到 `asia-southeast1`，与 `firebase.json` 和 v2 (`algoliaSync.js`) 对齐，解决 Flutter 客户端 callable 404 的 P0 阻断问题。

## 范围
- `functions/src/` 5 个 v1 模块的所有 `.region('asia-east1')` 调用
- `client/lib/data/repositories/` 客户端硬编码的 region 常量及注释
- **不改**：业务逻辑、docs/ 文档（标注给 custodian）

## 实施步骤

1. [x] Grep 定位全部 `asia-east1` 出现点
2. [x] 修改 `functions/src/notifications.js`（5 处）
3. [x] 修改 `functions/src/ai.js`（5 处）
4. [x] 修改 `functions/src/deposits.js`（3 处）
5. [x] 修改 `functions/src/applications.js`（5 处）
6. [x] 修改 `functions/src/antiGhosting.js`（3 处）
7. [x] 修改 `client/lib/data/repositories/application_repository.dart`（region 常量）
8. [x] 修改 `client/lib/data/repositories/checkin_repository.dart`（注释）
9. [x] 修改 `client/lib/data/repositories/review_repository.dart`（注释）
10. [x] 验证 grep：源代码 0 匹配
11. [x] 落盘文档（task_plan.md / findings.md / progress.md）
12. [x] 更新根 findings.md 索引
13. [x] 请求 reviewer 审查

## 验收标准
- `functions/src/` 下 `asia-east1` 匹配数 = 0
- `client/lib/` 下 `asia-east1` 匹配数 = 0
- 客户端 `FirebaseFunctions.instanceFor(region:)` 使用 `asia-southeast1`
- 业务逻辑未改动
