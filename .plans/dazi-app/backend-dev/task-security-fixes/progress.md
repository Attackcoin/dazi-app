# task-security-fixes — 进度记录

## 2026-04-12

### 开始
- 读取 firestore.rules, deposits.js, applications.js, notifications.js, ai.js, antiGhosting.js
- 读取所有 repository 文件分析复合索引需求
- 确认所有 9 个问题均存在
- 创建任务文件夹

### 完成（2026-04-12）
- C-1: firestore.rules users 拆分 create/update，update 字段白名单（10 个可编辑字段）
- C-2: deposits.js 加 HMAC-SHA256 + timingSafeEqual + payChannel 枚举校验
- H-2: firestore.rules posts create/update 字段白名单，create 校验 userId == auth.uid
- H-3: firestore.indexes.json 补充 9 个索引（posts×3 + applications×3 + matches×3 + deposits×1）
- H-5: applications.js submitReview 改为复合 ID set() + ratingSum/ratingCount increment()
- H-6: notifications.js onNewApplication + onApplicationStatusChange 均加 postDoc.exists 检查
- H-7: ai.js parseVoicePost/generateDescription/generateIcebreakers 加 MAX_INPUT_LENGTH=2000 限制
- M-7: reviews 使用复合文档 ID `${matchId}_${fromUid}_${toUid}`，rules 层 !exists 双重保护
- M-8: openCheckinWindow 从 every 1 minutes 改为 every 5 minutes
