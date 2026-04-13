# dazi-app - 架构决策记录

---

## AD-1: 群聊架构 (2026-04-12)
- **决策**: 每个 post 对应一个群聊，postId = chatId
- **理由**: 简化数据模型，一个局一个聊天室

## AD-2: 状态管理 (2026-04-09)
- **决策**: Riverpod Provider + StreamProvider only, 禁止 Notifier/StateNotifier
- **理由**: 用户偏好，保持简单

## AD-3: 聊天存储 (2026-04-09)
- **决策**: Firebase Realtime Database 存消息，Firestore 存 lastMessage 摘要
- **理由**: RTDB 适合高频实时消息，Firestore 适合结构化查询
