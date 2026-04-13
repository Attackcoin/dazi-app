# dazi-app - 系统不变量

> 不可违反的系统边界。Reviewer 审查时必须检查。

---

## INV-1: Riverpod 模式限制
- 只用 Provider + StreamProvider[.family]
- 禁止 Notifier/StateNotifier/ChangeNotifier
- UI 本地状态用 setState

## INV-2: Firebase SDK 注入
- 必须通过 firebaseXxxProvider 构造注入
- 禁止 FirebaseXxx.instance 直接调用

## INV-3: 异步加载
- 统一用 AsyncValue<T> + .when
- 禁止自定义 {isLoading, error, data} 三件套

## INV-4: 群聊 = postId
- chatId 等于 postId，一个局一个群聊
- 消息存 Realtime Database，摘要同步到 Firestore posts

## INV-5: Functions 区域
- 所有 Cloud Functions 部署到 asia-southeast1
