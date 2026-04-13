# backend-dev - 工作日志

> 用于上下文恢复。压缩/重启后先读此文件。

---

## 2026-04-12 - T2 安全修复（task-security-fixes）

**状态：全部完成，等待 reviewer 复审**

修复了 reviewer [BLOCK] 审查报告中的 9 个问题：

| ID | 文件 | 问题 | 状态 |
|----|------|------|------|
| C-1 | firestore.rules:9 | users write 无字段白名单 | 完成 |
| C-2 | deposits.js:99-104 | 支付回调签名被注释 | 完成 |
| H-2 | firestore.rules:16-17 | posts create/update 无白名单 | 完成 |
| H-3 | firestore.indexes.json | 缺 9 个复合索引 | 完成 |
| H-5 | applications.js:278 | submitReview 全量查询 race condition | 完成 |
| H-6 | notifications.js:56-58 | postDoc.exists 未检查 | 完成 |
| H-7 | ai.js | AI 接口无输入长度限制 | 完成 |
| M-7 | firestore.rules reviews | 无防重复保护 | 完成 |
| M-8 | antiGhosting.js | openCheckinWindow 每分钟扫全表 | 完成 |

**下一步：请 reviewer 复审这批修改**
