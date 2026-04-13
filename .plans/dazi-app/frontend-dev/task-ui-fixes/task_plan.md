# task-ui-fixes — 任务计划

## 目标
修复 reviewer [BLOCK] 审查报告中的 HIGH 和 MEDIUM 前端/UI 问题。

## 验收标准
- P0 (HIGH): H-1 withdrawApplication、H-9 scannedUid 传递、H-10 error Scaffold 全部修复
- MEDIUM: M-1 距离筛选移除、M-2 重试按钮补全、M-3/M-4 硬编码颜色修复、M-5 聊天 N+1 优化
- flutter analyze 零错误

## 任务清单

### P0 - HIGH
- [x] H-1: withdrawApplication 改为 Cloud Function 调用
- [x] H-9: scannedUid 传递给 _submitCheckin 并发送给后端
- [x] H-10: post_detail_screen error 分支加 Scaffold + AppBar

### MEDIUM
- [x] M-1: 移除距离筛选 UI（MVP 不需要）
- [x] M-2: 补 review/messages/chat/checkin/recap_card 的重试按钮
- [x] M-3: checkin_screen 硬编码 Colors.amber/Colors.green → AppColors
- [x] M-4: post_detail/review 星评 Colors.amber → AppColors.starColor
- [x] M-5: 聊天 _getSenderName N+1 → 利用 senderName 冗余字段

## 文件路径
- `client/lib/data/repositories/application_repository.dart`
- `client/lib/presentation/features/checkin/checkin_screen.dart`
- `client/lib/presentation/features/post/post_detail_screen.dart`
- `client/lib/presentation/features/discover/discover_screen.dart`
- `client/lib/presentation/features/review/review_screen.dart`
- `client/lib/presentation/features/messages/messages_screen.dart`
- `client/lib/presentation/features/messages/chat_screen.dart`
- `client/lib/presentation/features/review/recap_card_screen.dart`
- `client/lib/core/theme/app_colors.dart`
