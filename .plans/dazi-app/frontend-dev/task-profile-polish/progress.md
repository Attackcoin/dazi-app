# task-profile-polish — progress

## 现状摘要（2026-04-09）

### 范围内的文件
- `client/lib/presentation/features/profile/profile_screen.dart` — 278 行，ConsumerWidget + `_ProfileView`
  - 已经有：头像/昵称/评分/统计行/兴趣标签/设置项/退出登录
  - 没有：信用分徽章（sesameAuthorized）、性别/年龄/城市/bio、分区（我发布/我申请/参加过）
  - 没有：骨架屏、图片错误 fallback、他人视角分支
  - 订阅的是 `currentAppUserProvider`（仅自己），无法展示他人主页
- `edit_profile_screen.dart` — 已实现昵称/简介/城市/兴趣标签编辑
- `emergency_contacts_screen.dart` / `notifications_settings_screen.dart` / `privacy_settings_screen.dart` / `blocked_users_screen.dart` — 设置子页，不在本次精调范围
- `client/lib/data/repositories/user_repository.dart` — 82 行，仅面向当前登录用户（`_uid` 从 auth 取）
  - 有：updateProfile / setEmergencyContacts / setNotificationsPrefs / setPrivacyPrefs / blockUser / unblockUser / watchBlockedProfiles
  - 没有：`watchUser(uid)` 只读流、`userByIdProvider`
- `client/lib/data/repositories/post_repository.dart` — 有 `watchFeed` / `watchPost`，没有 `watchPostsByUser`
- `client/lib/data/repositories/application_repository.dart` — 有 `watchMyApplication` / `watchApplicationsForPost`，没有 `watchApplicationsByApplicant`
- `client/lib/data/models/app_user.dart` — 22 个模型字段 + `age` getter + `isAdult`；fromFirestore 健全
- `client/lib/data/models/post.dart` — 帖子字段名是 `userId`（不是 `authorUid`）

### 约束
- CLAUDE.md SD-1..SD-4：只用 Provider + StreamProvider[.family]；禁 Notifier/freezed；AsyncValue.when；setState 写状态
- 任务禁止改动：app_router.dart / app_theme.dart / app_colors.dart / home_screen.dart / user_repository.dart 既有方法签名 / search 和 post 相关 / 建新 feature
- 不改路由：意味着无法新增 `/u/:uid` 路由。`ProfileScreen` 保留 `/profile` 单入口 = 自己，但加 `uid` 可选构造参数以便他人视角（widget 测试可直接传入）
- 不能 Write 新 .md（harness 限制）→ 测试 .dart 可以 Write；progress.md 先 Write 再 Edit 追加
