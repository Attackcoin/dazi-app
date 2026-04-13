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

