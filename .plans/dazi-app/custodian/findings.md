# custodian - 发现记录

> 工作中发现的问题和技术要点。

---

## 任务索引

| 任务文件夹 | 日期 | 摘要 |
|-----------|------|------|
| [audit-post-fix/](audit-post-fix/findings.md) | 2026-04-12 | 大修复后合规巡检。0 CRITICAL，8 ADVISORY（文档欠债为主）。所有 SD-1~SD-4 合规，无死代码。 |
| (回填) researcher 过期数据修正 | 2026-04-13 | [ADVISORY] researcher research-full-audit/findings.md 的 "SD-5 withOpacity 残留 16 处 / 10 文件" 段为过期快照。custodian 独立 grep 验证 `C:\dazi-app\client\lib` → 0 匹配;清理实际发生在 commits `714b2f8` + `14a7553`(4 reviewer WARN),早于 2026-04-13 盘点。已在 researcher findings 对应段落追加 `> [CUSTODIAN-2026-04-13 回填]` 块(保留原文,审计透明),并同步更新 `researcher/findings.md` 根索引状态行。交叉引用 frontend-dev `task-fix-high-sd5-and-split-profile/findings.md`。 |
| [audit-doc-rewrite/](audit-doc-rewrite/) | — | 文档重写审计 |
| [audit-phase3-compliance/](audit-phase3-compliance/) | — | 阶段3合规巡检 |

---
