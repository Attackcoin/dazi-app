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

### submitQuickFeedback (onCall)
- **请求**：`{ matchId, feedback: "met" | "no_show" }`
- **响应**：`{ success }`
- **校验**：`feedback` 必须是 `"met"` 或 `"no_show"`；调用者必须是 `match.participants` 成员
- **状态限制**：match.status 必须为 `completed` / `ghosted` / `ghosted_all`
- **幂等**：每个参与者只能提交一次，二次调用 throw `already-exists`
- **写入方式**：Admin SDK 点路径 `quickFeedback.{uid}` 更新（不走 rules）
- **触发时机**：match 完成或签到超时后，通过 FCM 推送 `quick_feedback` 类型通知提醒用户

### startIdentityVerification (onCall)
- **请求**：`{}`（无参数）
- **响应**：`{ clientSecret, verificationSessionId }`
- **前置**：已认证用户，`verificationLevel < 2`
- **错误码**：
  - `unauthenticated` — 未登录
  - `not-found` — 用户文档不存在
  - `already-exists` — 已完成证件验证（level >= 2）
  - `failed-precondition` — STRIPE_SECRET_KEY 未配置
- **内部**：创建 Stripe VerificationSession（type: 'document'），metadata 写入 uid
- **客户端使用**：拿 clientSecret 初始化 Stripe Identity SDK 前端验证流程

### stripeIdentityWebhook (onRequest, HTTP endpoint)
- **URL**：`https://asia-southeast1-<project>.cloudfunctions.net/stripeIdentityWebhook`
- **方法**：POST
- **签名验证**：Stripe webhook 签名（`stripe-signature` header + `STRIPE_WEBHOOK_SECRET` 环境变量）
- **处理的事件**：
  - `identity.verification_session.verified` — 从 session.metadata 取 uid，更新 `users/{uid}.verificationLevel` 为 2，写入 `verifiedAt` 服务端时间戳
  - `identity.verification_session.requires_input` — 记录日志（用户需补充输入）
- **响应**：`200 { received: true }`（所有合法签名的事件）；`400`（签名无效）；`500`（STRIPE_WEBHOOK_SECRET 未配置）
- **环境变量**：`STRIPE_SECRET_KEY`、`STRIPE_WEBHOOK_SECRET`
- **部署注意**：需在 Stripe Dashboard 配置 webhook endpoint URL 和订阅 `identity.verification_session.*` 事件

### createSeriesPosts (onCall)
- **请求**：`{ templatePost: { title, description, category, time (ISO string), location, totalSlots, minSlots, gender, genderQuota, costType, depositAmount, images, tags, isSocialAnxietyFriendly, isInstant }, recurrence: "weekly" | "biweekly", totalWeeks: 2-8 }`
- **响应**：`{ seriesId, postIds: string[] }`
- **逻辑**：
  - 认证检查 + 参数验证（totalWeeks 2-8 整数，recurrence 合法）
  - 生成 seriesId（Firestore auto-ID）
  - 获取用户信息（publisherName, publisherAvatar）
  - batch write 创建 totalWeeks 个 post 文档
  - 第 N 个帖子 time = baseTime + (N-1) * 7天(weekly) 或 14天(biweekly)
  - title 格式：`${originalTitle}（第${week}/${totalWeeks}周）`
  - 每个文档设置：seriesId, recurrence, seriesWeek (1-N), seriesTotalWeeks
  - 标准初始值：status='open', waitlist=[], acceptedGender={male:0,female:0}
- **错误码**：
  - `unauthenticated` — 未登录
  - `invalid-argument` — templatePost/recurrence/totalWeeks 参数非法
  - `not-found` — 用户文档不存在
- **Post 新增字段**：`seriesId` (String), `recurrence` ("weekly"|"biweekly"), `seriesWeek` (int, 1-based), `seriesTotalWeeks` (int)
- **索引**：posts 复合索引 `seriesId ASC + seriesWeek ASC`（查询同系列所有帖子）
- **Rules**：seriesId/recurrence/seriesWeek/seriesTotalWeeks 在 posts create 白名单中，不在 update 白名单（创建后不可改）

### confirmSafety (onCall)
- **请求**：`{}`（无参数）
- **响应**：`{ success: true }`
- **逻辑**：查找当前用户最新的 `safetyAlerts` 中 `status=='pending'` 的记录，更新为 `confirmed` + 写入 `confirmedAt`
- **错误码**：
  - `unauthenticated` — 未登录
  - `not-found` — 没有待确认的安全提醒
- **触发前提**：`onCheckinTimeout` 检测到未签到用户且该用户设置了紧急联系人时，自动创建 `safetyAlerts/{matchId}_{uid}` 文档并推送 FCM 通知

### escalateSafetyAlert (scheduled, `every 10 minutes`)
- **逻辑**：查询 `safetyAlerts` 中 `status=='pending'` 且 `expiresAt <= now` 的文档
  - 更新 status 为 `escalated` + 写入 `escalatedAt`
  - MVP 阶段：记录日志 + 给用户发强提醒推送（"你的紧急联系人已被通知"）
  - 后续版本：发送短信/邮件给紧急联系人
- **安全流程时间线**：未签到 → 创建 alert(pending, 30min TTL) → 用户可 `confirmSafety` → 30min 过期 → `escalateSafetyAlert` 升级

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
| posts | 帖子/局 | title, category, time, location, totalSlots, status, seriesId?, recurrence?, seriesWeek?, seriesTotalWeeks? |
| applications | 申请记录 | postId, applicantId, status |
| matches | 匹配记录 | postId, participants, quickFeedback |
| reviews | 评价 | fromUid, toUid, postId, rating, tags |
| categories | 分类配置 | id, label, emoji |
| safetyAlerts | 安全提醒 | matchId, uid, emergencyContacts, status(pending/confirmed/escalated), expiresAt |

## Realtime Database

| 路径 | 用途 |
|------|------|
| chats/{postId}/messages/{msgId} | 群聊消息 |
