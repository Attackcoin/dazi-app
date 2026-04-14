# T1 后端安全/并发修复任务清单

基线: master 当前 HEAD  
依据: `.plans/dazi-app/reviewer/review-full-audit/findings.md`  
决策文件: `C:\Users\CRISP\.claude\plans\lazy-fluttering-chipmunk.md` PART A  
范围: 7 HIGH + 4 MEDIUM + Jest 基建 + Doc-Code Sync

## 修复清单

| ID | 严重度 | 文件 | 状态 |
|----|--------|------|------|
| 阶段 0 | 基建 | functions/package.json + __tests__/setup.js | pending |
| H-6 | HIGH | functions/src/ai.js (generateIcebreakers + generateRecapCard onCall) | pending |
| H-2 | HIGH | functions/src/applications.js submitReview toUserId 校验 | pending |
| H-5 | HIGH | functions/src/antiGhosting.js ghostCount → increment + applyToPost 入口下沉 | pending |
| M-3 | MED | firestore.rules applications create | pending |
| H-1 | HIGH | functions/src/applications.js applyToPost 确定性 id | pending |
| H-3 | HIGH | functions/src/applications.js submitReview 事务化 | pending |
| H-4 + M-1 | HIGH | functions/src/antiGhosting.js submitCheckin runTransaction + CAS + GPS 强制 | pending |
| H-7 | HIGH | functions/src/deposits.js freezeDeposit + callback 幂等 | pending |
| M-9 | MED | functions/src/applications.js acceptApplication 满员清理 pending | pending |
| M-5 | MED | functions/src/ai.js generateMonthlyReports Promise.all + month label | pending |
| 阶段 3 | Doc | docs/api-contracts.md + docs/architecture.md | pending |
| 阶段 4 | CI | python scripts/run_ci.py | pending |

## 范围外(不做)

- M-2 openCheckinWindow 复合索引(T2)
- M-8 v1/v2 SDK 迁移(T2)  
- _releaseDeposits / _processGhostDeposits 真实支付接入
- RD-5 i18n/a11y 全量
- rules-unit-testing 框架(backlog AUTOMATE-1)

## 验收

- 25+ jest 用例覆盖 H-1~H-7 + M-1/3/5/9
- `python scripts/run_ci.py` 全 PASS
- api-contracts.md + architecture.md 同步
- reviewer 可将 RD-4 升至 ADEQUATE
