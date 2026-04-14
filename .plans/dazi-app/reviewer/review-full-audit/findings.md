# T0b 全面深度审查 — Findings (独立复核 2026-04-13)

**审查员**: reviewer | **基线**: master@b415e19 | **基于**: researcher T0a findings + 独立复核
**范围**: 73 dart + 8 js + rules/indexes
**防偏袒**: 按面值评分,researcher 已标为 OK 的条目也独立验证

---

## 维度评分(本次)

| # | 维度 | 评分 | 差异 vs T0a |
|---|------|------|-------|
| RD-1 UI 精美度 | ADEQUATE (近 STRONG) | Glass Morph 100%,withOpacity=0 已清零,profile_screen 327 行 |
| RD-2 产品边界 | ADEQUATE | 骨架+空态+AsyncValue.when 完整,扣 6 处 retry 缺失 + GPS 签到绕过 |
| RD-3 Firebase 成本 | ADEQUATE | 索引 15 条 + limit + atomic increment;扣 v1/v2 混用 + 无缩略图 |
| RD-4 测试覆盖 | **WEAK** | 核心 6 个 repo + 8 个 .js 全部 0 单测,rules 0 回归 |
| RD-5 a11y/i18n | **WEAK** | i18n 0 基建,Semantics 仅 16 处 |

**总体判决**: [WARN] — 无 CRITICAL 残留,但发现 7 个新 HIGH(独立复核时被 researcher T0a 漏标)。RD-4/5 WEAK → 不能 [OK]。

---

## CRITICAL(0)

T0a 原 2 CRIT 已闭环,独立复核确认 `firestore.rules` + `deposits.js:147` HMAC 都就位。无新 CRITICAL。

---

## HIGH(新发现 / 独立复核加固)

### H-1 [NEW] applyToPost existingApp 检查非事务读,并发可创建重复申请
- **file**: `functions/src/applications.js:35-42`
- **证据**: existingApp 用 `db.collection().where().get()`(非 `tx.get`),与后续 `tx.set(appRef)` 之间有 race。两个并发请求都看到 empty → 都写入 → 同一用户同帖子出现 2 条 pending 申请。
- **修复**: 方案 A 用确定性 doc id `${postId}_${uid}` + `tx.get(docRef)` 检查 exists;方案 B 在事务内做 where 查询(Firestore 允许但仅单范围)。推荐 A。
- **[AUTOMATE]**: 补单测模拟并发。

### H-2 [NEW] submitReview 未校验 toUserId 是否为 match 参与者
- **file**: `functions/src/applications.js:265-309`
- **证据**: L279 校验 `fromUid ∈ participants`,但 L297 `toUser: toUserId` 直接用前端传入的 uid。可对任意 uid 写 review,污染他人 ratingSum/ratingCount。
- **修复**: `if (!match.participants.includes(toUserId) || toUserId === fromUid) throw permission-denied`。

### H-3 [NEW] submitReview 写 review + 更新 user rating 分两步非事务
- **file**: `functions/src/applications.js:294-309`
- **证据**: `reviewRef.set` 和 `users.doc(toUserId).update({ratingSum:increment})` 是两个独立 await。第一步成功第二步失败(网络/权限)→ review 存在但 ratingSum 没加,均值永久偏差。
- **修复**: 用 `db.runTransaction` 或 `batch.commit`。

### H-4 [NEW] submitCheckin 非事务,arrayUnion 后 re-get 判断 allCheckedIn 存在并发双触发
- **file**: `functions/src/antiGhosting.js:110-120`
- **证据**: 2 个参与者同时点签到 → 两次 update(arrayUnion)顺利,但两次都 re-get 看到 `checkedIn == participants`,都调 `_onAllCheckedIn`。该函数对 post 做 `status:'done'` 更新(幂等)但 **totalMeetups `increment(1)`** 会执行 2 次,每人 +2。
- **修复**: 把签到 + allCheckedIn 判断合并进 `runTransaction`,或在 _onAllCheckedIn 前先用 `status == 'confirmed'` 做 CAS。
- **[AUTOMATE]**: 并发测试。

### H-5 [NEW] onCheckinTimeout ghostCount 用 read-modify-write,丢计数
- **file**: `functions/src/antiGhosting.js:163-170`
- **证据**: `const newCount = (userDoc.data().ghostCount || 0) + 1; batch.update({ghostCount:newCount, isRestricted: newCount>=3})`。若同一用户同时超时 2 个 match,两次 read 都看到旧值 → 丢一次爽约。
- **修复**: 改 `FieldValue.increment(1)`;isRestricted 判断放到 onUserUpdate 触发器(或接受宽松判断,下次超时再限制)。

### H-6 [NEW] generateIcebreakers / generateRecapCard (onCall) 未校验调用者 ∈ participants
- **file**: `functions/src/ai.js:123-179` + `ai.js:187-194`
- **证据**: L128 直接用前端传入的 matchId 取 match,未检查 `context.auth.uid ∈ match.participants`。任何登录用户可对任意 matchId 调用,生成内容包含对方 tags / 帖子信息 → 隐私泄漏 + API 配额滥用。
- **修复**: 接入 participants 检查,与 submitCheckin/submitReview 一致。

### H-7 [NEW] freezeDeposit + depositPaymentCallback 缺幂等性
- **file**: `functions/src/deposits.js:93-124, 152-166`
- **证据**:
  - freezeDeposit 每次调用 `deposits.add(...)` 无唯一性约束,用户重复点击可创建多条 pending_payment 记录(orderId 不同)。
  - depositPaymentCallback 只凭 `status === 'SUCCESS'` 就把状态写为 `frozen`,未校验当前状态(若已 refunded/ghost_deducted,会被覆盖)。
- **修复**: freezeDeposit 用确定性 id `${matchId}_${uid}` + exists 检查;callback 用事务 + `currentStatus === 'pending_payment'` 校验。

### H-8 [INHERIT] RD-4 测试覆盖极弱(沿用 T0a,独立复核)
- **证据**: `client/test/` 仅 9 个,核心 Repository(auth/application/match/chat/review/checkin/user/category)= 0;`functions/__tests__/` 目录不存在,8 个 .js 全部 0 单测;firestore.rules 无 `@firebase/rules-unit-testing` 回归(AUTOMATE-1 仍 open)。
- **修复**: **最小必要测试集**(reviewer 建议优先):
  1. `applications.js` 事务类(applyToPost 并发/acceptApplication 事务回滚/submitReview 幂等)
  2. `antiGhosting.js` (submitCheckin 并发/onCheckinTimeout ghost 计数)
  3. `deposits.js` (freezeDeposit 幂等 + callback 状态机)
  4. `firestore.rules` 回归(users 白名单/posts create status=open 约束/applications update 仅发布者)
  5. client: `application_repository` + `auth_repository` + `chat_repository`
- **[AUTOMATE]**: 全部列为 T1 input。

### H-9 [INHERIT] RD-5 i18n 全空 + Semantics 覆盖 <20%
- **证据**: 独立 grep `import.*intl|AppLocalizations|S\.of\(context` → 0 匹配。全项目 UI 文案硬编码中文。`Semantics(` 16 处/9 文件,swipe/chat_input/review/checkin/messages/onboarding 关键交互零语义。图片 alt 全缺。
- **判定**: 对 MVP(国内上线)**非阻塞**;若上架海外市场或适老化审核则阻塞。
- **修复**: backlog,T1 不必须。

---

## MEDIUM

### M-1 submitCheckin GPS 校验可前端绕过
- **file**: `antiGhosting.js:93`
- **证据**: `if (lat && lng)` — 前端不传坐标直接跳过距离校验。防鸽子系统核心约束失效。
- **修复**: post 有 location 时强制要求客户端上报坐标,否则拒绝签到(降级策略另做旗标)。

### M-2 openCheckinWindow 仍每 5 分钟全扫,无索引
- **file**: `antiGhosting.js:23-36`
- **证据**: where(status==confirmed).where(checkinWindowOpen==false).where(meetTime ∈ range) 4 个条件,`firestore.indexes.json` 无此复合索引。
- **修复**: 加索引;并考虑改用 `onDocumentWrite` 触发 + Cloud Tasks 延时(meetTime + 0 秒)。

### M-3 applications create rules 未限制 applicantId == auth.uid
- **file**: `firestore.rules:75`
- **证据**: `allow create: if request.auth != null;` — 可代他人写申请(即使 Function 层控制,防御纵深不足)。
- **修复**: `&& request.resource.data.applicantId == request.auth.uid && request.resource.data.status == 'pending'`。

### M-4 chat_screen.dart N+1 senderName(沿用 T0a)
- **file**: `client/lib/presentation/features/messages/chat_screen.dart:179` 附近
- **修复**: 建 senderId → name 缓存或从 match.participantInfo 取。

### M-5 generateMonthlyReports 串行 + 月份标签错误
- **file**: `functions/src/ai.js:283-301`
- **证据**: `for (uid of userIds) { await claude.messages.create() }` 100 用户将接近 9 min 超时;L297 `getMonth()` 是"当前月"(0-indexed)而非"上月",padStart 也不对(1 月会写 `2026-00`)。
- **修复**: `Promise.all` 分批 + 正确 month 标签 `String(monthStart.getMonth()+1).padStart(2,'0')`。

### M-6 6 处 error 分支无 retry(沿用 T0a)
- post_detail / review / messages / chat / checkin / recap_card
- **修复**: 参考 home_screen 标准错误 widget。

### M-7 发现页距离筛选 UI 误导
- **file**: `discover_screen.dart:112,148`
- **修复**: 落地或从 UI 移除。

### M-8 v1/v2 Functions SDK 混用
- **file**: `algoliaSync.js` 用 v2,其他用 v1。
- **修复**: 统一到 v2(推荐,性能+冷启动优势)或全部 v1。

### M-9 acceptApplication 后未处理其他 pending 申请
- **file**: `applications.js:97-176`
- **证据**: post 变 `full` 后,剩余 pending 申请仍停留到 24h 自然过期。用户体验差 + 占数据。
- **修复**: 满员时把同 post 的 pending 申请批量转 `waitlisted` 或 `auto_rejected`。

---

## LOW

- L-1 硬编码常量(ghost_threshold=3、openCheckinWindow window=30min、chat preview=30/40)散落,未集中
- L-2 `home_screen.dart:14-21` 城市数组硬编码
- L-3 Profile 参加过 Tab 只有数字(profile_tabs.dart:185)
- L-4 回忆卡分享 stub (recap_card_screen.dart:52)
- L-5 破冰话题无前端入口(ai.js:111 孤儿 Function)
- L-6 候补晋升 Function 缺失(waitlist 只加不出)
- L-7 帖子到期 Function 缺失(open → expired 无自动推进)
- L-8 deposits.js:89 dead code(sesameScore 字段不存在,逻辑永为 false)
