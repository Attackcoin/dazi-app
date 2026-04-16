# MVP Launch (免押金版) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the app to production with all core flows working end-to-end (发帖→申请→匹配→签到→评价), deposits deferred to v1.1.

**Architecture:** Post model gets denormalized `publisherName`/`publisherAvatar` written at create time (avoids N+1 reads on home feed). Algolia search works via existing `syncPostToAlgolia` trigger. FCM push via existing `notifications.js`. Crashlytics added as Flutter plugin. Production Firebase project deployed with rules + indexes + functions.

**Tech Stack:** Flutter 3.27+ / Firebase Functions Node.js / Firestore / Algolia / FCM / Crashlytics

---

## File Structure

### New files
- `client/lib/core/services/crashlytics_service.dart` — Crashlytics init + error handler wrapper

### Modified files
- `client/lib/data/models/post.dart` — Add `publisherName`, `publisherAvatar` fields
- `client/lib/data/repositories/post_create_repository.dart:134-164` — Write denormalized publisher fields at create
- `client/lib/presentation/features/home/widgets/post_card.dart:107-129` — Use real publisher data
- `client/lib/presentation/features/post/post_detail_screen.dart:215` — Remove placeholder TODO
- `client/lib/data/repositories/search_repository.dart` — Parse `publisherName` from Algolia hit
- `firestore.rules:49-54` — Add `publisherName`, `publisherAvatar` to posts create whitelist
- `functions/src/algoliaSync.js:40-58` — Sync `publisherName` to Algolia record
- `client/lib/main.dart` — Add Crashlytics init
- `client/pubspec.yaml` — Add `firebase_crashlytics` dependency

### Config files (no code — deploy/environment)
- `functions/.env` — Production secrets (Algolia, Claude, etc.)
- Firebase console — FCM APNs key, Android SHA-1

---

## Task 1: Post 模型增加发布者冗余字段

**Files:**
- Modify: `client/lib/data/models/post.dart`
- Modify: `client/lib/data/repositories/post_create_repository.dart:134-164`
- Modify: `firestore.rules:49-54`
- Modify: `functions/src/algoliaSync.js:40-58`
- Test: `functions/__tests__/applications.test.js` (seedPost 更新)

### Why
首页 PostCard 显示发布者头像和昵称。当前每张卡片都要额外 `get('users/{userId}')` = N+1 问题。冗余写入 `publisherName`/`publisherAvatar` 到 post 文档，一次读取全搞定。

- [ ] **Step 1: 更新 firestore.rules posts create 白名单**

在 `firestore.rules` 的 posts create `hasOnly` 列表中添加 `publisherName` 和 `publisherAvatar`：

```
// 现有白名单末尾加两个字段：
'userId', 'title', 'description', 'category', 'time',
'location', 'totalSlots', 'minSlots', 'gender', 'genderQuota',
'costType', 'depositAmount', 'images', 'tags',
'isSocialAnxietyFriendly', 'isInstant', 'status',
'acceptedGender', 'waitlist', 'createdAt', 'updatedAt', 'expiresAt',
'publisherName', 'publisherAvatar'
```

- [ ] **Step 2: Post model 加字段**

在 `client/lib/data/models/post.dart` 的 `Post` class 中：

```dart
// 新增字段（构造函数 + fromFirestore + fromAlgoliaHit）
final String? publisherName;
final String? publisherAvatar;
```

`fromFirestore` 加：
```dart
publisherName: data['publisherName'] as String?,
publisherAvatar: data['publisherAvatar'] as String?,
```

`fromAlgoliaHit` 加：
```dart
publisherName: hit['publisherName'] as String?,
publisherAvatar: null, // Algolia 不同步头像 URL
```

- [ ] **Step 3: post_create_repository 写入冗余字段**

在 `post_create_repository.dart` 的 `doc.set({...})` 中，读取当前用户的 name + avatar 并写入：

```dart
// 在 doc.set 之前获取用户信息
final userDoc = await _firestore.collection('users').doc(user.uid).get();
final userData = userDoc.data() ?? {};

// doc.set 中增加：
'publisherName': userData['name'] as String? ?? '',
'publisherAvatar': userData['avatar'] as String? ?? '',
```

- [ ] **Step 4: algoliaSync 同步 publisherName**

在 `functions/src/algoliaSync.js` 的 `toAlgoliaRecord` 中增加：

```js
publisherName: data.publisherName || '',
```

（不同步 avatar URL 到 Algolia，避免泄露存储路径）

- [ ] **Step 5: 跑 CI 验证**

```bash
cd C:/Users/CRISP/OneDrive/文档/dazi-app && python scripts/run_ci.py
```

Expected: CI 全绿。

- [ ] **Step 6: Commit**

```bash
git add client/lib/data/models/post.dart \
  client/lib/data/repositories/post_create_repository.dart \
  firestore.rules functions/src/algoliaSync.js
git commit -m "feat: denormalize publisherName/Avatar on post create"
```

---

## Task 2: PostCard / PostDetail 使用真实发布者数据

**Files:**
- Modify: `client/lib/presentation/features/home/widgets/post_card.dart:107-129`
- Modify: `client/lib/presentation/features/post/post_detail_screen.dart:215`

- [ ] **Step 1: PostCard 使用 post.publisherName/Avatar**

在 `post_card.dart` 的 `_buildPublisherRow` 中：

```dart
// 替换 CircleAvatar child：
CircleAvatar(
  radius: 12,
  backgroundColor: gt.colors.glassL2Bg,
  backgroundImage: post.publisherAvatar != null && post.publisherAvatar!.isNotEmpty
      ? NetworkImage(post.publisherAvatar!)
      : null,
  child: post.publisherAvatar == null || post.publisherAvatar!.isEmpty
      ? Icon(Icons.person, size: 14, color: gt.colors.textTertiary)
      : null,
),

// 替换 Text：
Text(
  post.publisherName ?? '搭子用户',
  ...
),
```

删除对应的 TODO 注释。

- [ ] **Step 2: PostDetail 移除 participantAvatarUrls TODO**

`post_detail_screen.dart:215` 的 TODO 注释改为简短说明：
```dart
// participantAvatarUrls 从 match.participantInfo 获取，帖子详情页暂不展示
```

- [ ] **Step 3: 跑 flutter analyze + widget tests**

```bash
cd client && flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git add client/lib/presentation/features/home/widgets/post_card.dart \
  client/lib/presentation/features/post/post_detail_screen.dart
git commit -m "feat: PostCard shows real publisher name and avatar"
```

---

## Task 3: 接入 Crashlytics

**Files:**
- Modify: `client/pubspec.yaml`
- Create: `client/lib/core/services/crashlytics_service.dart`
- Modify: `client/lib/main.dart`

- [ ] **Step 1: 添加依赖**

```bash
cd client && flutter pub add firebase_crashlytics
```

- [ ] **Step 2: 创建 crashlytics_service.dart**

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

Future<void> initCrashlytics() async {
  // Debug 模式不上报
  if (kDebugMode) return;

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}
```

- [ ] **Step 3: main.dart 中初始化**

在 `main()` 的 `Firebase.initializeApp()` 之后、`runApp()` 之前加：

```dart
import 'core/services/crashlytics_service.dart';

// 在 main() 中：
await initCrashlytics();
```

- [ ] **Step 4: 跑 flutter analyze**

```bash
cd client && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git add client/pubspec.yaml client/pubspec.lock \
  client/lib/core/services/crashlytics_service.dart \
  client/lib/main.dart
git commit -m "feat: add Firebase Crashlytics for production error tracking"
```

---

## Task 4: 生产环境配置 & 部署

**Files:**
- Modify: `functions/.env` (不提交 git)
- Firebase console 操作

### 这是运维任务，非代码。需要人工在 Firebase Console / 命令行完成。

- [ ] **Step 1: 创建或确认生产 Firebase 项目**

```bash
firebase projects:list
# 如果没有生产项目：
firebase projects:create dazi-app-prod --display-name "搭子 App"
```

- [ ] **Step 2: 切换到生产项目并生成客户端配置**

```bash
firebase use dazi-app-prod
cd client && flutterfire configure --project=dazi-app-prod
```

这会重新生成 `firebase_options.dart`。

- [ ] **Step 3: 配置 Functions 环境变量**

```bash
cd functions
# 创建 .env 文件（不提交 git）
cat > .env << 'ENVEOF'
ALGOLIA_APP_ID=<your-algolia-app-id>
ALGOLIA_ADMIN_KEY=<your-algolia-admin-key>
CLAUDE_API_KEY=<your-claude-api-key>
ADMIN_SECRET=<random-32-char-string>
ENVEOF
```

- [ ] **Step 4: 部署 Firestore Rules + Indexes**

```bash
cd C:/Users/CRISP/OneDrive/文档/dazi-app
firebase deploy --only firestore:rules,firestore:indexes
# 索引构建需要几分钟，在 Firebase Console > Firestore > Indexes 监控进度
```

- [ ] **Step 5: 部署 Storage Rules**

```bash
firebase deploy --only storage
```

- [ ] **Step 6: 部署 Cloud Functions**

```bash
firebase deploy --only functions
```

⚠️ **DEPLOY-2 提醒**：如果之前有 `asia-east1` 的旧函数实例，部署后 **2 分钟内** 执行：
```bash
firebase functions:delete <function-name> --region=asia-east1
```
（完整函数列表在 `.plans/dazi-app/reviewer/review-unify-region/findings.md`）

- [ ] **Step 7: 运行 Algolia 回填**

```bash
curl -X POST https://asia-southeast1-dazi-app-prod.cloudfunctions.net/algoliaBackfill \
  -H "X-Admin-Secret: <your-admin-secret>"
```

- [ ] **Step 8: 验证生产环境**

在 Firebase Console 检查：
- Auth > 能创建测试用户
- Firestore > Rules playground 测试读写
- Functions > 日志无错误
- Algolia dashboard > posts index 有数据

---

## Task 5: FCM 推送配置

- [ ] **Step 1: Android FCM**

Firebase Console > Project Settings > Cloud Messaging：
- 下载 `google-services.json` 放到 `client/android/app/`
- 确认 SHA-1 / SHA-256 fingerprint 已添加

- [ ] **Step 2: iOS APNs**

Firebase Console > Project Settings > Cloud Messaging > Apple app：
- 上传 APNs Authentication Key (.p8) 或 APNs Certificate
- 记录 Key ID 和 Team ID

- [ ] **Step 3: 客户端请求通知权限**

检查 `client/lib/main.dart` 或 onboarding flow 中是否有：
```dart
await FirebaseMessaging.instance.requestPermission();
final token = await FirebaseMessaging.instance.getToken();
// 存到 users/{uid}.fcmToken
```

如果没有，需要补上。

---

## Task 6: 平台构建 & 上架

- [ ] **Step 1: Android AAB 构建**

```bash
cd client
flutter build appbundle --release --dart-define=USE_EMULATOR=false
# 输出：build/app/outputs/bundle/release/app-release.aab
```

需要：签名密钥 (`upload-keystore.jks`) + `key.properties`

- [ ] **Step 2: iOS IPA 构建**

```bash
cd client
flutter build ipa --release --dart-define=USE_EMULATOR=false
# 需要 Xcode + Apple Developer 账号 + provisioning profile
```

- [ ] **Step 3: Web 构建 + 部署**

```bash
cd client && flutter build web --release --dart-define=USE_EMULATOR=false
cd .. && firebase deploy --only hosting
```

- [ ] **Step 4: 上传到应用商店**

- Google Play Console：上传 AAB + 填写商店列表
- App Store Connect：通过 Xcode / Transporter 上传 IPA
- 准备：隐私政策 URL、应用截图、应用描述

---

## Task 7: 上线前 Smoke Test

- [ ] **Step 1: 生产环境 E2E 手动走查**

用真实手机号完成：
1. 注册/登录（OTP 短信到达）
2. 完成 onboarding（头像、昵称、城市）
3. 发帖（免押金）
4. 另一个账号申请
5. 原账号接受 → 匹配创建
6. 群聊发消息
7. 签到（需到活动地点或跳过 GPS 检查）
8. 双方互评

- [ ] **Step 2: 推送通知验证**

确认以下场景收到推送：
- 收到新申请
- 申请被接受
- 群聊新消息
- 签到窗口开启提醒

- [ ] **Step 3: 搜索验证**

在搜索页输入关键词，确认 Algolia 返回结果。

---

## 延后到 v1.1 的事项

| 事项 | 原因 |
|------|------|
| 微信/支付宝押金 | 需要支付牌照/服务商对接，周期 2-4 周 |
| 阿里云实人认证 | 非 MVP 必需，可后续加 |
| 语音 AI 发帖 | 需要 STT 接入 |
| 地图选点 | 需要 Maps API Key + UI |
| 国际化 | MVP 只做中文 |
| J8 deposits E2E | 随押金功能一起做 |
