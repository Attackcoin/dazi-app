# T0a 全面代码库盘点 — Findings

**扫描时间**: 2026-04-12
**扫描范围**: client/lib/ (65 Dart 文件) + functions/src/ (8 JS 文件)

---

## 1. 功能完整性

### 完成度总览

| 功能 | 完成度 | 说明 |
|------|--------|------|
| 注册/登录 | 完整 | 手机验证码 |
| Onboarding | 完整 | 5步骤 |
| 滑卡Swipe | 完整 | swipe_screen.dart:773行 |
| 首页Feed | 完整 | 骨架屏+城市切换 |
| 发现页 | 部分 | 距离筛选UI有逻辑缺失 |
| 发帖 | 完整 | AI语音+AI描述 |
| 帖子详情 | 完整 | 双视角 |
| 群聊 | 完整 | RTDB+图片 |
| 消息列表 | 完整 | 按match分组 |
| 签到 | 完整 | 二维码+GPS |
| 评价 | 完整 | 星级+标签+文字 |
| 回忆卡 | 部分 | 分享为stub |
| 个人主页 | 完整 | 自己/他人视角 |
| 搜索 | 完整 | Algolia+debounce |
| 推送通知(后端) | 完整 | FCM 12种场景 |
| 防鸽子系统(后端) | 完整 | 签到/爽约/勋章 |
| 押金系统 | 部分 | 支付SDK为TODO |

### 缺失/不完整功能

- [STUB] 回忆卡分享: recap_card_screen.dart:52
- [UI无逻辑] 发现页距离筛选: discover_screen.dart:112 _applyLocalFilters无距离逻辑
- [TODO] 押金支付: deposits.js:67-71
- [TODO] 押金扣除/释放: antiGhosting.js:282-289 只有console.log
- [TODO] 地图选点: create_post_screen.dart:23注释
- [降级] STT语音: create_post_screen.dart:184 改为文字输入框
- [无Function] 候补晋升: waitlist字段存在但无自动晋升Function
- [前端缺入口] 破冰话题: ai.js:111 generateIcebreakers实现了但客户端无调用
- [摘要展示] Profile参加过Tab: profile_tabs.dart:185 只有totalMeetups数字


---

## 2. 代码质量问题

### 大文件（均未超800行黄金原则阈值，严重度LOW）

- swipe_screen.dart: 773行
- profile_screen.dart: 771行
- create_post_screen.dart: 721行
- discover_screen.dart: 560行

### 大函数

- swipe_screen.dart:249 _buildCardStack() ~120行，可拆分
- applications.js:97 acceptApplication ~80行（事务+多文档）
- create_post_screen.dart:97 _publish() ~55行

### 硬编码值（严重度MEDIUM）

- home_screen.dart:14-21: _cnCities/_globalCities城市数组，建议移到Firestore config
- antiGhosting.js:165: ghostCount >= 3 限制阈值，建议提取 GHOST_THRESHOLD
- antiGhosting.js:33,44: 30分钟/60分钟窗口，建议命名常量
- chat_repository.dart:80: 消息预览截断长度30/40

### 错误处理缺失

- [HIGH] notifications.js:62 onNewApplication: 未检查postDoc.exists，post已删除时crash
- [HIGH] post_create_repository.dart:124 deletePost: 直接delete无检查active申请
- [HIGH] applications.js:278 submitReview: allReviews全量查询无limit

### SD-1~SD-4 遵守情况

- SD-1 PASS: 全项目无Notifier/StateNotifier，本地状态全用setState
- SD-2 PASS: Firebase SDK全部通过Provider注入（auth_repository.dart:10-12）
- SD-3 PASS: 全部用AsyncValue.when，无自定义三件套
- SD-4 PASS: 无freezed/riverpod_generator

---

## 3. UI/UX 问题

### 缺少重试按钮的error分支（严重度MEDIUM）

以下页面error分支只显示文字无重试（参考home_screen.dart标准处理）:
- post_detail_screen.dart:31
- review_screen.dart:77
- messages_screen.dart:26
- chat_screen.dart:143
- checkin_screen.dart:127
- recap_card_screen.dart:67

### 硬编码颜色（严重度MEDIUM）

- checkin_screen.dart:180: Colors.amber -> AppColors.warningBg
- checkin_screen.dart:195: Colors.green -> AppColors.success.withValues(...)
- profile_screen.dart:339, review_screen.dart:179: Colors.amber(星评分) -> AppColors.starColor

### 距离筛选UI无效（严重度MEDIUM）

- discover_screen.dart:148: _DistanceFilter enum 4选项
- discover_screen.dart:112: _applyLocalFilters()中无距离逻辑
- 用户选择距离后无效果，属UI误导

---

## 4. 性能问题

### 缺失Firestore复合索引（严重度HIGH）

已有indexes覆盖主feed查询，以下查询缺失索引:

| 缺失查询 | 代码位置 |
|---------|---------|
| matches by participants arrayContains + lastMessageAt desc | match_repository.dart:20 |
| applications by applicantId + createdAt desc | application_repository.dart:96 |
| applications by postId + createdAt desc | application_repository.dart:78 |
| posts by userId + createdAt desc | post_repository.dart:50 |
| matches by status + checkinWindowOpen + checkinWindowExpiresAt | antiGhosting.js:132 |
| applications by status + expiresAt | applications.js:219 |
| reviews by matchId + fromUser + toUser | applications.js:257 |
| deposits by userId + matchId + status | deposits.js:136 |
| matches by status + meetTime range | notifications.js:123 |

### 无分页的列表（严重度HIGH）

- match_repository.dart:18 watchMyMatches: 无limit，全量拉取所有群聊
- application_repository.dart:78 watchApplicationsForPost: 无limit

### 全量计算评分均值（严重度HIGH）

- applications.js:278: 每次提交评价查全量reviews重算均值
- 建议: newRating = (existingRating * reviewCount + rating) / (reviewCount + 1)

### N+1查询（严重度MEDIUM）

- chat_screen.dart:179 _getSenderName(): 对每个发送者单独调ref.read(userByIdProvider(uid))

### 图片无缩略图（严重度MEDIUM）

- 上传图片最大1600px，Storage无缩略图，列表页加载原图
- 建议接入storage-resize-images Extension

---

## 5. 安全问题

### [CRITICAL] users写入无字段白名单

- firestore.rules:9: allow write: if request.auth.uid == userId
- 用户可直接写rating/ghostCount/isRestricted/totalMeetups/badges
- 建议: update加affectedKeys().hasOnly([...whitelist])

### [CRITICAL] 押金回调无签名验证

- deposits.js:99: HTTP endpoint depositPaymentCallback签名验证被注释
- 任何人可伪造POST把押金标为已冻结

### [HIGH] withdrawApplication与rules不匹配（功能性BUG）

- application_repository.dart:89: 前端直接.update({'status': 'withdrawn'})
- firestore.rules L28-31: applications update只允许帖子发布者
- 申请者调withdrawApplication会收到PERMISSION_DENIED

### [HIGH] posts create/update无字段限制

- firestore.rules:16: create任意字段（可写status:'done'）
- firestore.rules:17: 发布者update可改status/acceptedGender等系统字段

### [HIGH] AI接口无输入长度限制

- ai.js:37 parseVoicePost: text无上限
- ai.js:85 generateDescription: title无上限
- deposits.js:26: payChannel未验证为合法枚举值

### [MEDIUM] reviews rules层无防重复

- firestore.rules:58: allow create: if request.auth != null（无!exists检查）

---

## 6. 测试覆盖

### 已有测试（5个文件）

- data/repositories/post_create_repository_test.dart
- data/repositories/search_repository_test.dart
- presentation/features/home/home_screen_test.dart
- presentation/features/profile/profile_screen_test.dart
- presentation/features/search/search_screen_test.dart

### 关键模块无测试（严重度HIGH）

| 模块 | 重要性 |
|------|--------|
| auth_repository.dart | 极高——登录核心流程 |
| application_repository.dart | 极高——申请核心流程 |
| match_repository.dart | 高 |
| chat_repository.dart | 高 |
| review_repository.dart | 高 |
| checkin_repository.dart | 高 |
| Firebase Functions JS (applications.js事务) | 极高 |

---

## 7. Firebase Functions

### 已部署Functions（23个）

onCall: applyToPost, acceptApplication, rejectApplication, submitReview, parseVoicePost, generateDescription, generateIcebreakers, generateRecapCard, submitCheckin, registerFcmToken, freezeDeposit, refundDeposit

PubSub定时: expireApplications(60min), openCheckinWindow(1min), onCheckinTimeout(5min), sendPreMeetingReminder(30min), generateMonthlyReports(月1日)

Firestore触发器: onNewApplication, onApplicationStatusChange, onMonthlyReportGenerated, syncPostToAlgolia

onRequest: depositPaymentCallback, algoliaBackfill

### 问题Functions

- [HIGH] generateIcebreakers: ai.js:111实现了，客户端无任何调用入口
- [HIGH] openCheckinWindow: 每1分钟全局扫描，Firestore成本高
- [MEDIUM] v1/v2 SDK混用: algoliaSync.js用v2，其余用v1
- [MEDIUM] generateMonthlyReports: for循环串行调Claude API，100用户接近9min超时

### 缺失Functions

| 缺失 | 优先级 |
|------|--------|
| 候补晋升(waitlist->accepted) | HIGH |
| 帖子到期处理(open->expired) | HIGH |
| isRestricted后撤销pending申请 | MEDIUM |
| accepted撤回时post full->open回滚 | MEDIUM |

---

## 汇总：按严重度

### CRITICAL（上线前必须修复）

1. firestore.rules:9 users写入无字段白名单，rating/ghostCount/isRestricted可被篡改
2. deposits.js:99 押金回调无签名验证

### HIGH（MVP前强烈建议修复）

3. firestore.rules:16-17 posts create/update无字段白名单
4. application_repository.dart:89 withdrawApplication -> PERMISSION_DENIED（功能BUG）
5. 缺失9个Firestore复合索引（见4.1节）
6. match_repository.dart:18 / application_repository.dart:78 无limit
7. applications.js:278 全量查询重算评分
8. notifications.js:62 未检查postDoc.exists
9. AI接口无输入长度限制
10. auth/application/match/chat/review/checkin Repository无单测

### MEDIUM（发布后迭代）

11. 发现页距离筛选UI有逻辑无（discover_screen.dart:112）
12. 6个Screen error分支无重试按钮
13. 聊天N+1 senderName查询（chat_screen.dart:179）
14. Firebase Storage无缩略图
15. reviews rules层无防重复保护
16. v1/v2 SDK混用
17. openCheckinWindow高频扫描

### LOW（Backlog）

18. 回忆卡分享stub
19. 破冰话题无前端入口
20. Profile参加过Tab只有数字
21. 候补晋升/帖子到期/状态回滚Functions缺失
22. 硬编码城市列表/魔法数字/Colors.amber
23. generateMonthlyReports串行调用超时风险

---

*基于完整源码静态阅读，不含运行时测试结果。researcher 2026-04-12*


---

## 增量复核 2026-04-13 (researcher)

> 基于 2026-04-12 版 findings,重新抓取当前 HEAD 状态并补扫 Glass Morph / i18n / a11y / 文件规模维度。

### [OK] 原 CRITICAL/HIGH 已闭环

- [OK] firestore.rules:12-33 users 字段白名单 + rating/ghostCount/isRestricted 创建时必须默认值;update 只允许业务字段。原 C1 关闭。
- [OK] firestore.rules:42-65 posts 字段白名单,create status 强制 'open',update 只放行业务字段 + status=cancelled。原 H3 关闭。
- [OK] deposits.js:147 verifyCallbackSignature HMAC-SHA256 已接入。原 C2 关闭。
- [OK] application_repository.dart:91 withdrawApplication 改走 httpsCallable。原 H-BUG 关闭。
- [OK] firestore.indexes.json 15 条索引覆盖 posts/applications/matches/reviews/deposits 全部热点查询(含 participants arrayContains + lastMessageAt、applicantId+createdAt、matches status+meetTime 等原缺失 9 条)。原 H-IDX 关闭。
- [OK] match_repository.dart:23 / application_repository.dart:84,105 全部加 .limit。原 H-PERF 关闭。
- [OK] applications.js:304-309 submitReview 改为原子 increment(ratingSum/ratingCount),均值在前端算。原 H-AVG 关闭。
- [OK] reviews rules:108 复合 ID + !exists 防重复 + Function 层双保险。原 M-REV 关闭。
- [OK] Functions 全部 .region('asia-southeast1') 统一。

### [BUG] SD-5 违反:withOpacity 残留 16 处 / 10 文件

透明度必须用 `color.withValues(alpha: x)`(Flutter 3.27+),但仍有残留:
- `glass_button.dart:1` / `home_screen.dart:1` / `create_post_screen.dart:2` / `search_screen.dart:1` / `post_detail_screen.dart:1` / `post_card.dart:2` / `profile_screen.dart:8` / `discover_screen.dart` / `chat_screen.dart` / `messages_screen.dart` / `swipe_screen.dart` / `recap_card_screen.dart` / `message_bubble.dart` / `apply_sheet.dart`
- 其中 `profile_screen.dart` 独占 8 处,是最大违规源。

> [CUSTODIAN-2026-04-13 回填]
> 本条目已过期,不再成立。custodian 独立再验证 `grep -rn 'withOpacity(' C:\dazi-app\client\lib` → **0 匹配 / 0 文件**,baseline 实际已清零。
> 清理在本次审计之前已由 commits `714b2f8` + `14a7553`(后者为 "4 reviewer WARN")提前完成,本段数据为盘点时过期快照,非实际违规。
> 交叉引用:`C:\dazi-app\.plans\dazi-app\frontend-dev\task-fix-high-sd5-and-split-profile\findings.md` 的 baseline 验证小节。
> 保留原文以审计透明,实际 SD-5 withOpacity 违规数 = 0。

### [GAP] 黄金原则 800 行阈值被突破

- `profile_screen.dart` **820 行 > 800**(上次 custodian audit 时 770,已越线),必须拆分。建议抽出 tab 子 widget 和 settings section。
- `swipe_screen.dart` 709 / `create_post_screen.dart` 686 / `post_detail_screen.dart` 561 / `discover_screen.dart` 486 / `home_screen.dart` 483 / `chat_screen.dart` 382:未超阈值但偏大,纳入 backlog。

### [GAP] RD-5 i18n 全空

- 全项目 grep `intl|AppLocalizations|\.tr\(|S\.of\(` → **0 匹配**
- 所有 UI 文案硬编码中文字面量,无任何 arb/翻译基础设施
- 若要出海或支持繁体,需先引入 `flutter_localizations + intl` + `extract_to_arb`

### [GAP] RD-5 a11y 覆盖不均

- `Semantics(` 仅 16 处,分布在 9 个文件:glass_button(1)、create_post(2)、home_screen(1)、search(1)、post_detail(1)、profile_screen(7)、post_card(2 含 1 个 ExcludeSemantics)
- 未覆盖的关键交互:swipe_screen 的滑卡按钮、chat_input_bar 发送按钮、review_screen 星级打分、checkin_screen 的扫码/生成 QR 按钮、messages_screen 的 match tile、onboarding 各步骤的选择控件
- 图片(post images / avatar)无 alt 语义

### [RESEARCH] 测试覆盖现状

client/test (9 个):
- data/repositories/post_create_repository_test.dart
- data/repositories/search_repository_test.dart
- presentation/features/home/home_screen_test.dart
- presentation/features/profile/profile_screen_test.dart
- presentation/features/search/search_screen_test.dart
- core/theme/dazi_colors_test.dart (新)
- core/widgets/glass_button_test.dart (新)
- core/widgets/glass_card_test.dart (新)
- widget_test.dart

client/integration_test (5 个 journey):
- journey_login_test / journey_feed_apply_test / journey_post_create_test / journey_profile_test / journey_smoke_test

**缺口**:auth/application/match/chat/review/checkin/user/category Repository 无单测;functions/src/ 全部 0 单测;Firestore rules 无回归测试(原 AUTOMATE-1 仍 open)。

### [RESEARCH] TODO 扫描(当前)

- `deposits.js:26,107,144,206`:押金 SDK + 真实签名验证接入
- `antiGhosting.js:92,285,290`:押金扣款/解冻接入
- `create_post_screen.dart:30,189`:地图选点 + STT 语音
- `post_card.dart:105,115,121,205,210`:Post model 缺 publisher/participant avatar 字段
- `post_detail_screen.dart:229`:同上 participantAvatarUrls

### [RESEARCH] listener/snapshots 盘点(共 13 处)

auth_repository:28(user doc) / application_repository:72,85,106 / category_repository:24 / match_repository:24,29 / post_repository:36,42,55 / user_repository:48,109。均通过 StreamProvider 暴露,Riverpod 自动 dispose。**建议 reviewer 复核**:每个 StreamProvider 是否 family 化正确,以及 UI autoDispose 策略是否被误用(family 不 autoDispose 会内存泄漏)。

### 评级

- RD-1 UI 精美度:**ADEQUATE** (Glass Morph 覆盖完整,withOpacity 16 处扣分)
- RD-2 产品边界:**ADEQUATE** (有骨架+空态,error retry 6 处缺失扣分)
- RD-3 Firebase 成本:**ADEQUATE** (索引+limit+atomic 已做,v1/v2 混用 + 无缩略图 + openCheckinWindow 1min 扣分)
- RD-4 测试覆盖:**WEAK** (核心 repo + functions 0 单测)
- RD-5 a11y/i18n:**WEAK** (i18n 0 基建,Semantics 覆盖 <20%)

*researcher 2026-04-13*
