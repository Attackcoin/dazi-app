# backend-dev - 发现记录

> 工作中发现的问题和技术要点。

---

## 任务索引

| 任务文件夹 | 状态 | 摘要 |
|-----------|------|------|
| [task-security-fixes/](task-security-fixes/) | 完成 | 修复 reviewer [BLOCK] 的 9 个 CRITICAL/HIGH/MEDIUM 安全问题 |
| [task-t1-security-fixes/](task-t1-security-fixes/) | 完成 2026-04-14 | T1 全面审查后 7 HIGH + 4 MED 并发/鉴权修复 + Jest 基建；reviewer [OK] |
| [task-v2-migration-eval/](task-v2-migration-eval/) | 完成 2026-04-14 | M-8 v1→v2 迁移评估 — 推荐 DEFERRED，触发条件见第 6 节 |

---

## task-security-fixes 关键结论

### 修复清单（2026-04-12）

- **C-1** `firestore.rules` users 拆分 create/update，update 限制 10 个可编辑字段，保护 rating/ghostCount/isRestricted/badges
- **C-2** `deposits.js` 加 `HMAC-SHA256 + timingSafeEqual` 临时签名验证（需配置 `PAYMENT_CALLBACK_SECRET` 环境变量）；加 payChannel 枚举校验（'wechat'|'alipay'）
- **H-2** `firestore.rules` posts create 加字段白名单 + `userId == auth.uid` 校验；update 限制可改字段集合
- **H-3** `firestore.indexes.json` 补充 9 个复合索引：posts(userId+createdAt, status+createdAt)，applications(postId+applicantId+createdAt, postId+createdAt, applicantId+createdAt)，matches(participants+lastMessageAt, status+meetTime, status+checkinWindowOpen+checkinWindowExpiresAt)，deposits(userId+matchId+status)
- **H-5** `applications.js` submitReview 改为复合文档 ID `.set()` + `ratingSum/ratingCount FieldValue.increment()` 原子更新，消除全量查询 race condition
- **H-6** `notifications.js` onNewApplication 和 onApplicationStatusChange 均加 `if (!postDoc.exists) return null`
- **H-7** `ai.js` 所有 AI 入口加 `MAX_INPUT_LENGTH = 2000` 字符校验
- **M-7** `reviews` 改用复合文档 ID `${matchId}_${fromUid}_${toUid}`，rules 层 `!exists` 双重防护
- **M-8** `antiGhosting.js` openCheckinWindow 调度从 `every 1 minutes` 改为 `every 5 minutes`

### 需要后续操作
- 部署前需配置 Firebase Functions 环境变量：`PAYMENT_CALLBACK_SECRET`（任意强随机字符串）
- 前端 submitReview 调用不需改动（复合 ID 在后端生成）
- 用户展示 rating 建议改为读 `ratingSum / ratingCount` 计算（替换旧的 `rating` 字段），否则旧数据不一致
