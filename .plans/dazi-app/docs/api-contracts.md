# dazi-app - API 契约

> Dev 变更 API 时必须同步更新此文件。

## Firebase Functions 端点 (asia-southeast1)

### applyToPost (onCall)
- **请求**：`{ postId }`
- **响应**：`{ success, applicationId, status }`
- **applicationId 语义**：固定 `${postId}_${uid}`（H-1 确定性 docId，幂等，二次调用 throw `already-exists`）
- **status**：`pending` / `waitlisted`
- **前置**：用户 `isRestricted==false` 且 `ghostCount < 3`（H-5），否则 `permission-denied`

### acceptApplication (onCall)
- **请求**：`{ applicationId }`
- **响应**：`{ success, matchId }`
- **副作用**：创建 `matches/{matchId}`；若 post 达到 `totalSlots-1`，自动把其它 `pending` 申请批量改为 `auto_rejected`（M-9）

### submitReview (onCall)
- **请求**：`{ matchId, toUserId, rating (1-5), comment?, tags? }`
- **响应**：`{ success }`
- **原子保证**：review 写入 + `users/{toUserId}.ratingSum/ratingCount` 增量在同一 runTransaction 内提交（H-3）
- **校验**：`toUserId` 必须在 `match.participants` 且 `!== fromUid`（H-2）
- **幂等**：复合 docId `${matchId}_${fromUid}_${toUserId}`，二次 `already-exists`

### submitCheckin (onCall)
- **请求**：`{ matchId, lat?, lng? }`
- **响应**：`{ success, allCheckedIn }`
- **GPS 强制**：若 `post.location.lat/lng` 存在，客户端必须上报 `lat/lng` 数字（M-1），否则 `invalid-argument`；距离 > 500m 返回 `out-of-range`
- **事务保证**：全签到后 CAS 把 match→completed、post→done、所有参与者 `totalMeetups++` 在同一 runTransaction 内完成（H-4）

### freezeDeposit (onCall)
- **请求**：`{ matchId, payChannel: 'wechat'|'alipay' }`
- **响应**：`{ success, orderId?, amount?, method?, alreadyFrozen?, resumed? }`
- **幂等**：depositId = `${matchId}_${uid}`（H-7）；
  - 已 `frozen`/`sesame_guaranteed` → 返回 `alreadyFrozen`
  - 已 `pending_payment` → 复用原 orderId，`resumed:true`
  - 已 `refunded`/`ghost_deducted` → `failed-precondition`

### depositPaymentCallback (onRequest, Webhook)
- **签名**：目前 HMAC-SHA256 (`x-dazi-signature` header + `PAYMENT_CALLBACK_SECRET` 环境变量)
- **CAS**：SUCCESS 分支在 runTransaction 内检查 `status==pending_payment` 才转 `frozen`；已 `frozen` 幂等 no-op；其他状态 warn 后 no-op（H-7）

### generateIcebreakers / generateRecapCard (onCall)
- **鉴权**：仅 `match.participants.includes(context.auth.uid)` 可调用（H-6）
- **内部函数** `_generateRecapCard` 不加校验，由 `antiGhosting` 可信路径触发

### generateMonthlyReports (scheduled, `5 0 1 * *` Asia/Shanghai)
- **month label**：`${monthStart.getFullYear()}-${String(monthStart.getMonth()+1).padStart(2,'0')}`（M-5 修 `getMonth()` 本月/上月偏移 bug）
- **并发**：分批 `BATCH=10` 用 `Promise.all`，每批 try/catch 独立

## Firestore Collections

| Collection | 用途 | 关键字段 |
|-----------|------|---------|
| users | 用户信息 | name, avatar, city, tags, rating |
| posts | 帖子/局 | title, category, time, location, totalSlots, status |
| applications | 申请记录 | postId, applicantId, status |
| matches | 匹配记录 | postId, participants |
| reviews | 评价 | fromUid, toUid, postId, rating, tags |
| categories | 分类配置 | id, label, emoji |

## Realtime Database

| 路径 | 用途 |
|------|------|
| chats/{postId}/messages/{msgId} | 群聊消息 |
