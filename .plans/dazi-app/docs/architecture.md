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

## 安全与并发

### 事务化收银台（T1 2026-04-13）

所有涉及"读-判断-写"的业务（申请、签到、押金、评价）都走 `db.runTransaction`，在事务内做 CAS 判定，避免竞态。

- **确定性 docId 幂等**：`applications/${postId}_${uid}`（H-1）、`deposits/${matchId}_${uid}`（H-7）、`reviews/${matchId}_${fromUid}_${toUid}`（H-3）。并发重复请求依赖 tx.get(existingRef) 判断，任一客户端二次调用都 throw `already-exists`。
- **状态机幂等**：`freezeDeposit` / `depositPaymentCallback` 按 `status ∈ {pending_payment, frozen, sesame_guaranteed, refunded, ghost_deducted}` 分支返回，避免重复扣款；支付回调在 tx 内 CAS `status==pending_payment` 才升 `frozen`。
- **原子递增**：`FieldValue.increment` 用于 `ratingSum` / `ratingCount` / `ghostCount` / `totalMeetups` / `acceptedGender.male|female`，避免 read-modify-write 丢失更新（H-5）。
- **一次性完成**：`submitCheckin` 最后一人到齐时 CAS 把 `match→completed`、`post→done`、所有参与者 `totalMeetups++` 在同一事务内提交（H-4）。非核心副作用（推送、押金释放、回忆卡、勋章）在事务外做。
- **鉴权边界**：`generateIcebreakers` / `generateRecapCard` onCall 层加 `participants.includes(auth.uid)`（H-6）；`submitReview` 校验 `toUserId` 为同 match 的其它参与者（H-2）。
- **字段白名单**：`firestore.rules` 在 `users` / `posts` / `applications` create/update 上做字段 keys().hasOnly + 值断言（M-3），防止客户端伪造风控字段。

### 测试保证
`functions/__tests__/{applications,antiGhosting,deposits}.test.js` 用内存版 FakeFirestore 覆盖 31 条用例（H-1~H-7 + M-1/M-9），每条高危修复都有正/反双向断言。
