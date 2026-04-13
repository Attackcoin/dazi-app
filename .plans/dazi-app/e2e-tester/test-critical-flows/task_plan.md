# T3: 验证关键流程 — 静态分析 + 代码走查

## 任务目标
对 backend-dev / frontend-dev 完成的一轮大修复进行代码走查验证，确认修复正确性、无回归、前后端一致。

## 输入
- CRITICAL 修复：firestore.rules 字段白名单、支付回调验签
- HIGH 修复：withdrawApplication 改 Cloud Function、签到 UID 传递、error 死路修复、复合索引、N+1 优化等
- MEDIUM 修复：距离筛选移除、error 重试按钮、硬编码颜色替换、聊天 senderName 等

## 验证项清单（11 项）
1. firestore.rules — users/posts 字段白名单
2. deposits.js — HMAC 签名验证逻辑
3. applications.js — reviews 复合文档 ID 一致性
4. withdrawApplication — 前后端参数对齐
5. checkin_screen.dart — scannedUid 传递链路
6. post_detail_screen.dart — error 分支完整性
7. app_colors.dart — starColor/successGreen 引用
8. discover_screen.dart — 距离筛选移除情况
9. 5 个 screen error 分支重试按钮
10. chat_screen.dart — senderName 及 N+1 问题
11. firestore.indexes.json — 索引覆盖

## 输出
- test-critical-flows/findings.md — 11 项 PASS/FAIL 详细报告
- flutter analyze 结果

## 状态
完成 — 2026-04-12
