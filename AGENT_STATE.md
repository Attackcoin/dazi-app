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

### 🔴 YOU — Next Manual Step
**Connect FlutterFlow to Firebase:**
1. Open https://flutterflow.io → your project
2. Left menu → Settings → Firebase → Connect Firebase
3. Select `dazi-dev`
4. Download and upload `google-services.json` (Android) + `GoogleService-Info.plist` (iOS)

**Also still needed (can do later):**
- Google Maps API Key → https://console.cloud.google.com
- Algolia account → https://www.algolia.com → create app `dazi-search`
- Fill remaining keys in `functions/.env`: ALGOLIA_APP_ID, ALGOLIA_ADMIN_KEY

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
| Frontend | FlutterFlow | Non-technical founder, iOS+Android from one codebase |
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
