# task-unify-region Progress

## 2026-04-09

- 收到任务：统一 Functions v1 区域到 `asia-southeast1`（P0）
- Grep 定位：`functions/src/` 21 处 `.region('asia-east1')`，分布于 notifications/ai/deposits/applications/antiGhosting 五个模块
- Grep 定位：`client/lib/data/repositories/` 1 处运行时常量（application_repository.dart:9）+ 2 处注释（checkin_repository.dart:10、review_repository.dart:10）
- 发现：checkin_repository 和 review_repository 共享 application_repository 的 `firebaseFunctionsProvider`，实际运行时只有一个 region 常量，改一处同时修复三个
- 完成：所有 21 处 functions 代码替换（使用 Edit replace_all）
- 完成：客户端 1 处常量 + 2 处注释更新
- 验证：`Grep asia-east1` 在源代码目录 0 匹配，剩余 22 条全部在 `.plans/dazi-app/` 文档/计划/审计，符合预期
- 输出：task_plan.md / findings.md / progress.md，更新根 findings.md 索引
- 标注给 custodian：docs/architecture.md L43/L56 和 docs/api-contracts.md L222-266 需同步更新（非本任务范围）
- 标注部署前注意事项：v1 region 变更需手动删除老实例；Firestore 触发器 + Pub/Sub 定时任务在双 region 并存期间会重复执行；`depositPaymentCallback` webhook URL 变更需同步更新支付平台配置
- 请求 reviewer 审查
