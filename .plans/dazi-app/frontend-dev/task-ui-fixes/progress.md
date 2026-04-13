# task-ui-fixes — 进度

## 2026-04-12

### 完成
- [x] H-1: withdrawApplication → Cloud Function 调用（不再直写 Firestore）
- [x] H-9: scannedUid 传递给 _submitCheckin 和后端 submitCheckin Function
- [x] H-10: post_detail_screen error 分支加 Scaffold + AppBar + 重试按钮
- [x] M-1: 移除距离筛选 UI（discover_screen）
- [x] M-2: review/messages/chat/checkin/recap_card 补重试按钮
- [x] M-3: checkin_screen Colors.amber/green → AppColors.starColor/successGreen
- [x] M-4: post_detail/review Colors.amber → AppColors.starColor
- [x] M-5: chat_screen N+1 优化：ChatMessage 新增 senderName 冗余字段，_getSenderName 不再查 Firestore
- [x] flutter analyze: 零错误

### 待协调
- H-1 需要 backend-dev 实现 `withdrawApplication` Cloud Function
