# dazi-app - 发现与技术记录

> 由团队智能体自动更新。每条标注来源。

---

## custodian — audit-post-fix（2026-04-12）

大修复后合规巡检完成。**0 CRITICAL，8 ADVISORY**。

关键发现：
- [ADVISORY] `api-contracts.md` reviews 字段名错误（fromUid/toUid → 应为 fromUser/toUser + matchId）
- [ADVISORY] `api-contracts.md` 的 24 个 Cloud Functions 端点未填充
- [ADVISORY] `architecture.md` 缺 deposits / reports / monthlyReports 三个 Firestore Collection
- [ADVISORY] 建议新增 KP-6：deposits.js freezeDeposit 在 MVP 阶段是 dead code
- [ADVISORY] swipe_screen.dart（772行）和 profile_screen.dart（770行）接近 800 行上限，建议计划拆分
- [OK] 距离筛选死代码已完全清除，SD-1~SD-4 全部合规，Colors.xxx 使用均为白/黑叠加场景可接受

详见 `.plans/dazi-app/custodian/audit-post-fix/findings.md`

---
