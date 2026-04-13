# task-security-fixes — 任务计划

## 目标
按 P0 优先级修复 reviewer [BLOCK] 审查报告中的后端 CRITICAL/HIGH/MEDIUM 安全问题。

## 验收标准
- C-1: firestore.rules users 拆分 create/update，update 有字段白名单
- C-2: deposits.js 加 HMAC 签名验证 + payChannel 枚举校验
- H-2: firestore.rules posts create/update 字段白名单
- H-3: firestore.indexes.json 补齐 9 个缺失复合索引
- H-5: submitReview 改为 FieldValue.increment() 原子更新
- H-6: notifications.js onNewApplication 加 postDoc.exists 检查
- H-7: ai.js 各入口加 2000 字符长度限制
- M-7: reviews 使用复合文档 ID 防重复
- M-8: openCheckinWindow 频率从每分钟降低到每 5 分钟

## 文件位置
- `firestore.rules`（项目根目录）
- `firestore.indexes.json`（项目根目录）
- `functions/src/deposits.js`
- `functions/src/applications.js`
- `functions/src/notifications.js`
- `functions/src/ai.js`
- `functions/src/antiGhosting.js`

## 状态
- [x] 任务文件夹创建完毕
- [x] C-1 修复（firestore.rules users 拆分 create/update + update 字段白名单）
- [x] C-2 修复（deposits.js HMAC-SHA256 验证 + payChannel 枚举）
- [x] H-2 修复（firestore.rules posts create/update 字段白名单）
- [x] H-3 修复（firestore.indexes.json 补充 9 个复合索引）
- [x] H-5 修复（submitReview 改为 increment() 原子更新）
- [x] H-6 修复（notifications.js 加 postDoc.exists 检查）
- [x] H-7 修复（ai.js 各入口加 2000 字符限制）
- [x] M-7 修复（reviews 改复合文档 ID + rules 层 exists 检查）
- [x] M-8 修复（openCheckinWindow 频率从 1 分钟改为 5 分钟）
