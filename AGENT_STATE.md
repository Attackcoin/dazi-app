# 搭子 App — Agent State

> Updated after every task completion. Claude reads this at session start to resume work.

---

## Completed Tasks

### [2026-03-08] Project Setup
- ✅ Full product design document written (`docs/design/design-document.md`)
- ✅ Implementation plan written (`docs/plans/implementation-plan.md`) — 24 Tasks across 8 phases
- ✅ README.md created
- ✅ GitHub repo created and all files pushed → https://github.com/Attackcoin/dazi-app
- ✅ AGENT_STATE.md created

### [2026-04-09] Flutter 前端脚手架（放弃 FlutterFlow 转纯 Flutter）
- ✅ `client/` — Flutter 项目脚手架（Android + iOS 平台）
- ✅ `pubspec.yaml` — 依赖：riverpod、go_router、firebase_*、cached_network_image 等
- ✅ `lib/core/theme/` — 品牌色系 + Material 3 主题（与 H5 落地页一致）
- ✅ `lib/core/router/app_router.dart` — go_router + 鉴权守卫
- ✅ `lib/data/models/` — Post、AppUser 模型（Firestore 序列化）
- ✅ `lib/data/repositories/auth_repository.dart` — 手机号登录（verifyPhoneNumber + 自动建档）
- ✅ `lib/data/repositories/post_repository.dart` — 广场 feed stream、帖子详情 stream
- ✅ Splash / Login / PhoneVerify / Home（广场+分类）/ HomeShell（底部导航）/ PostDetail / Profile
- ✅ `flutter analyze` 零错误零警告
- ✅ `client/README.md` — 首次运行指南
- ⚠️ `firebase_options.dart` 是占位文件，运行前必须执行 `flutterfire configure --project=dazi-dev`

### [2026-04-09] H5 落地页 + Algolia 同步 + API 申请清单
- ✅ `public/index.html` — App 下载/介绍页（支持 UA 自动匹配平台按钮）
- ✅ `public/post.html` — 帖子分享页（通过 Firestore Web SDK 读取帖子数据）
- ✅ `public/privacy.html` — 隐私政策（App Store 审核必须）
- ✅ `public/terms.html` — 用户协议
- ✅ `firebase.json` — 新增 hosting 配置，`/p/:id` 路由到 post.html
- ✅ `functions/src/algoliaSync.js` — Firestore → Algolia 自动同步 + 全量回填 HTTP 函数
- ✅ `functions/package.json` — 添加 `algoliasearch` 依赖
- ✅ `docs/setup/api-keys-checklist.md` — 所有第三方 API 申请指南
- ✅ `docs/setup/hosting-deploy.md` — H5 部署步骤

### [2026-03-08] Firebase Backend Code
- ✅ `functions/src/ai.js` — All Claude Haiku integrations (voice parse, description, icebreakers, recap card, monthly report)
- ✅ `functions/src/antiGhosting.js` — Check-in window, GPS validation, ghost count, badge awards
- ✅ `functions/src/applications.js` — Apply, accept, reject, 24h auto-expire, gender quota validation, review+rating
- ✅ `functions/src/deposits.js` — Freeze, payment callback, refund with time-based ratio
- ✅ `functions/src/notifications.js` — FCM push for 12 trigger scenarios
- ✅ `firestore.rules` — Complete security rules
- ✅ `firestore.indexes.json` — Composite indexes for key queries
- ✅ `firebase.json` — Project config + Emulator setup
- ✅ `.gitignore` — Protects API keys from being committed

---

## Next Tasks

### ✅ Completed This Session
- Firebase CLI installed (v15.9.0)
- `firebase login` completed
- `firebase init` run: Firestore + Functions + Emulators configured
- `functions/` dependencies installed (`npm install`)
- All 20 Cloud Functions deployed to `dazi-dev` ✅
- Firestore Security Rules deployed ✅
- Firestore Indexes deployed ✅
- Claude API Key set in `functions/.env`

### 🔴 YOU — Next Manual Step (BLOCKED: FlutterFlow 免费版限制)

**问题：** FlutterFlow 免费版无法连接 Firebase，Connect Firebase 按钮是灰色的。

**解决方案（二选一）：**

**方案 A（推荐）：升级 FlutterFlow**
- FlutterFlow → Settings → Billing → 升级 Standard 计划（$30/月）
- 升级后：Settings → Firebase → Connect Firebase → 选 `dazi-dev`
- 在 Firebase Console → Project Settings → 添加 Web 应用 → 复制 firebaseConfig 填入 FlutterFlow

**方案 B：换其他前端工具（开发周期会大幅延长，不推荐）**

**仍需用户手动申请**（详见 `docs/setup/api-keys-checklist.md`）:
- Google Maps API Key → https://console.cloud.google.com
- Algolia account → https://www.algolia.com → create index `posts`
- 填写 `functions/.env`: ALGOLIA_APP_ID / ALGOLIA_ADMIN_KEY
- （付费/后期）阿里云实人认证、微信支付、支付宝

**可立即部署**：
- `firebase deploy --only hosting` → H5 页面上线（需先替换 post.html 中的 firebaseConfig）
- `firebase deploy --only functions:syncPostToAlgolia` → 配置 Algolia 密钥后部署同步函数

### ⬅️ CLAUDE — Next Code Task (Phase 3: FlutterFlow Custom Code)
Once FlutterFlow is connected to Firebase, Claude will write:
- Custom Action: `callParseVoicePost` — calls deployed Firebase Function for voice AI publishing
- Custom Action: `calculateMatchScore` — local Dart algorithm for match % display
- Custom Action: `compressAndUploadImage` — client-side compression before Firebase Storage upload
- Custom Widget: `GenderQuotaBar` — real-time male/female slot progress bar
- Then: page-by-page build guide (Login → Onboarding → 广场 → Post → Chat → Profile)

---

## Important Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Frontend | ~~FlutterFlow~~ → **纯 Flutter** (2026-04-09) | FlutterFlow 免费版不能连 Firebase，Claude Code 可直接写 Dart |
| Backend | Firebase | Integrated auth/db/functions/push, fast iteration |
| Chat DB | Firebase Realtime Database | Low-latency for real-time messages |
| Main DB | Firestore | Flexible queries for all other data |
| AI | Claude Haiku API | Low cost (~¥0.003/call), good Chinese support |
| Voice | Device native STT (iOS/Android built-in) | Free, no extra API needed |
| Search | Algolia | Firestore lacks Chinese tokenization |
| Identity | Aliyun 实人认证 | Phone OTP → liveness → ID card (3 levels) |
| Payment | WeChat Pay + Alipay 担保交易 | Avoids 二清 violation, money stays with payment processor |
| Credit | 支付宝芝麻信用 API | 750+ score = full deposit waiver |
| Sharing | Native share + H5 landing page + DeepLink | WeChat/朋友圈/小红书/微博 |
| Environments | dazi-dev / dazi-staging / dazi-prod | Never mix, all changes go Dev→Staging→Prod |
| API Keys | Firebase Functions env vars only | Never expose keys to frontend |
| Market | Domestic China first, international (HK company) later | Validate product before overseas expansion |
| Feature Flags | Firebase Remote Config | Toggle features without app release |

---

## Key File Paths

| File | Purpose |
|------|---------|
| `docs/design/design-document.md` | Complete product design (all features, data models, AI matrix) |
| `docs/plans/implementation-plan.md` | 24-task step-by-step build plan |
| `AGENT_STATE.md` | This file — resume point for next session |

---

## Architecture Reference

```
Frontend:  FlutterFlow → iOS + Android
Backend:   Firebase
  ├── Auth            → Phone OTP / Google / Apple
  ├── Firestore       → Main database
  ├── Realtime DB     → Chat messages
  ├── Cloud Functions → Business logic (anti-ghosting, AI proxy, deposits)
  ├── FCM             → Push notifications
  └── Storage         → Images / videos / avatars
AI:        Claude Haiku (via Firebase Function proxy)
Maps:      Google Maps API
Search:    Algolia
Identity:  Aliyun 实人认证
Payment:   WeChat Pay + Alipay (担保交易 escrow)
Credit:    支付宝芝麻信用 API
```
