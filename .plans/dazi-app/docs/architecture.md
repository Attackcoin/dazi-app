# dazi-app - 系统架构

## 技术栈
- 客户端: Flutter (Dart) + Riverpod
- 后端: Firebase Functions (Node.js, asia-southeast1)
- 数据库: Firestore (主存储) + Realtime Database (聊天消息)
- 搜索: Algolia
- 存储: Firebase Storage (头像、帖子图片)
- 认证: Firebase Auth (手机号 OTP)

## 数据流
1. 用户注册/登录 → Firebase Auth
2. 发帖 → Firestore posts collection → Algolia 同步
3. 滑卡/加入 → Firestore applications → Cloud Functions 处理匹配
4. 群聊 → Realtime Database chats/{postId}/messages
5. 评价 → Firestore reviews collection

## 客户端架构
- lib/core/ — 主题、路由、常量
- lib/data/models/ — 数据模型
- lib/data/repositories/ — 数据访问层 (Riverpod Provider)
- lib/data/services/ — 第三方服务封装
- lib/presentation/features/ — 按功能分的 UI 页面
