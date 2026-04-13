# e2e-tester - 发现记录

> 工作中发现的问题和技术要点。

---

## T3 关键流程验证（2026-04-12）

详情：`test-critical-flows/findings.md`

- **结果：11/11 PASS，flutter analyze 零问题**
- CRITICAL 安全修复（rules 白名单、HMAC 验签）验证通过
- HIGH 功能修复（withdrawApplication、scannedUid、error 分支）验证通过
- MEDIUM UI 修复（starColor/successGreen、距离筛选移除、重试按钮、senderName N+1）验证通过
- 全部索引覆盖查询需求
- 轻微注意：discover_screen 中 `distance` 变量名实为城市名，建议改为 `cityLabel`（不影响功能）
