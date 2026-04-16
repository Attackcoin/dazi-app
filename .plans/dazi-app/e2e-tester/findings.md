# e2e-tester - 发现记录

> 工作中发现的问题和技术要点。

---

## T3 T1 修复 E2E 验证（2026-04-14 → 2026-04-16，已完成）

详情：`test-t3-t1-validation/task_plan.md`

- **Phase A**：J0-J4 回归运行 — **全部 PASS**（2026-04-15，commit 6f025eb）
- **Phase B**：J5 acceptApplication + M-9 auto_reject — **PASS**（2026-04-16）
  - 验证：M-9 满员批量 auto_reject、H-1 确定性 docId、match 创建事务、冗余字段写入
- **Phase C**：J6 submitCheckin（H-4 + M-1）— **PASS**（2026-04-16）
  - 验证：M-1 GPS 缺失→invalid-argument、远距离→out-of-range、近距离→成功
  - 验证：H-4 CAS 最后一人签到→match.status=completed + post.status=done + totalMeetups+1
  - 验证：重复签到→already-exists（幂等性）
- **Phase D**：J7 submitReview（H-2 + H-3）— **PASS**（2026-04-16）
  - 修复：signOut 后读 users 文档触发 permission-denied → 移到 signOut 前
  - 验证：H-2 toUserId=非参与者→permission-denied、自评→permission-denied
  - 验证：H-3 事务化 ratingSum/ratingCount 原子增量、复合 ID 防重→already-exists
- **J8 deposits HMAC callback** 延后（复杂度高）

### T1 修复覆盖汇总

| T1 修复 ID | 描述 | 覆盖 Journey |
|------------|------|-------------|
| H-1 | applyToPost 确定性 docId + CAS 幂等 | J5 |
| H-2 | submitReview toUserId 校验 | J7 |
| H-3 | submitReview 事务化 ratingSum | J7 |
| H-4 | submitCheckin CAS 最后一人 completed | J6 |
| M-1 | submitCheckin GPS 强制校验 | J6 |
| M-9 | acceptApplication 满员批量 auto_reject | J5 |

---

## T3 关键流程验证（2026-04-12）

详情：`test-critical-flows/findings.md`

- **结果：11/11 PASS，flutter analyze 零问题**
- CRITICAL 安全修复（rules 白名单、HMAC 验签）验证通过
- HIGH 功能修复（withdrawApplication、scannedUid、error 分支）验证通过
- MEDIUM UI 修复（starColor/successGreen、距离筛选移除、重试按钮、senderName N+1）验证通过
- 全部索引覆盖查询需求
- 轻微注意：discover_screen 中 `distance` 变量名实为城市名，建议改为 `cityLabel`（不影响功能）
