# researcher - 发现记录

> 工作中发现的问题和技术要点。

---

## 任务索引

| 任务 | 文件夹 | 状态 | 摘要 |
|------|--------|------|------|
| T0a 全面代码库盘点 | research-full-audit/ | 完成 2026-04-12 | 2 CRITICAL, 10 HIGH, 7 MEDIUM, 5 LOW |

详细发现见: `.plans/dazi-app/researcher/research-full-audit/findings.md`

---

## 重要发现速查

### CRITICAL
- C1: `firestore.rules:9` users写入无字段白名单，rating/ghostCount/isRestricted可被用户篡改
- C2: `deposits.js:99` 押金回调HTTP接口无签名验证，可被任意伪造

### HIGH（功能性BUG）
- H-BUG: `application_repository.dart:89` withdrawApplication直写Firestore但rules只允许帖子发布者update -> PERMISSION_DENIED
- H-IDX: 缺失9个Firestore复合索引（match/application/post/review/deposit查询）
- H-PERF: watchMyMatches/watchApplicationsForPost 无limit

---
