# e2e-tester - 发现记录

> 工作中发现的问题和技术要点。

---

## T3 T1 修复 E2E 验证（2026-04-14，进行中）

详情：`test-t3-t1-validation/task_plan.md`

- **Phase A**：J0-J4 回归运行（待执行）
- **Phase B**：J5 acceptApplication + M-9 auto_reject — **skeleton 已写入** [journey_accept_application_test.dart](client/integration_test/journey_accept_application_test.dart)
- **Phase C**：J6 submitCheckin（H-4 + M-1）— 待写
- **Phase D**：J7 submitReview（H-2 + H-3）— 待写
- **J8 deposits HMAC callback** 延后（复杂度高）

---

## T3 关键流程验证（2026-04-12）

详情：`test-critical-flows/findings.md`

- **结果：11/11 PASS，flutter analyze 零问题**
- CRITICAL 安全修复（rules 白名单、HMAC 验签）验证通过
- HIGH 功能修复（withdrawApplication、scannedUid、error 分支）验证通过
- MEDIUM UI 修复（starColor/successGreen、距离筛选移除、重试按钮、senderName N+1）验证通过
- 全部索引覆盖查询需求
- 轻微注意：discover_screen 中 `distance` 变量名实为城市名，建议改为 `cityLabel`（不影响功能）
