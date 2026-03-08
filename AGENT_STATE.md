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

---

## Next Tasks

### Phase 1 — Environment Setup (Task 1)
1. Register Firebase project — create 3 projects: `dazi-dev`, `dazi-staging`, `dazi-prod`
2. Enable Firebase services: Auth / Firestore / Realtime Database / Cloud Functions / FCM / Storage
3. Enable Auth providers: Phone OTP + Google + Apple
4. Register FlutterFlow account → connect to Firebase (`dazi-dev` first)
5. Apply for Google Maps API Key → configure in FlutterFlow
6. Apply for Claude Haiku API Key → store in Firebase Functions env vars (never in frontend)

### Phase 2 — Data Models (Task 2)
- Define Firestore collections in Firebase Console (or via code)
- Collections: `users`, `posts`, `applications`, `matches`, `deposits`, `reviews`, `reports`
- Subcollections: `chats/{chatId}/messages`
- Set Firebase Security Rules (rules defined in design doc)

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
