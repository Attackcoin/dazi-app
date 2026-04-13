# review-unify-region — 审查报告

**审查对象**：T1b Functions 区域统一（backend-dev 修改 24 处）
**审查日期**：2026-04-09
**审查者**：reviewer

## 判定

**[OK]** — 覆盖完整，代码侧零遗漏，2 条 DEPLOY 警告已由 CLAUDE.md Backlog 覆盖。

## 独立 grep 验证结果

| # | 命令 | 结果 |
|---|---|---|
| 1 | `Grep "asia-east1" functions/src` | **0 匹配** ✓ |
| 2 | `Grep "asia-east1" client/lib` | **0 匹配** ✓（含注释清理） |
| 3 | `Grep "\.region\(" functions` | **21 处全部 `asia-southeast1`** ✓ |
| 4 | `Grep "FirebaseFunctions\.instanceFor" client` | 1 处（application_repository.dart:12），指向 `asia-southeast1` ✓ |
| 5 | `Grep "'asia-\|\"asia-"` 全仓 | 源码侧仅余 `asia-southeast1` ✓ |
| 6 | `Grep "us-central1\|europe-\|asia-northeast"` 全仓 | 0 匹配 ✓ |

21 处 `.region()` 分布与 dev 自述完全吻合：
- notifications.js ×5 / ai.js ×5 / applications.js ×5 / deposits.js ×3 / antiGhosting.js ×3
- algoliaSync.js L64/L109 的 `{ region: 'asia-southeast1' }`（v2 写法）原本就正确，非本次修改

## 关键发现独立验证

dev 声称 checkin_repository 和 review_repository 从 application_repository 共享 `firebaseFunctionsProvider`，独立验证：

```
checkin_repository.dart:4  import 'application_repository.dart';
checkin_repository.dart:7  return CheckinRepository(functions: ref.watch(firebaseFunctionsProvider));
review_repository.dart:4   import 'application_repository.dart';
review_repository.dart:7   return ReviewRepository(functions: ref.watch(firebaseFunctionsProvider));
```

**dev 的洞察正确**，修复策略最小化且完整。

## 遗漏点清单

**代码侧无遗漏**。逐项扫描：

- `functions/index.js`：Firebase CLI 默认脚手架残留，`package.json main=src/index.js`，此文件未被使用
- `functions/src/index.js`：只做 admin.initializeApp + 重导出，无 region 配置
- `functions/src/env.example`：只含 `ALIYUN_REGION=cn-hangzhou`（阿里云实人认证 SDK，与 Firebase 无关）
- `functions/.env`：存在于 gitignore，若含 `FUNCTIONS_REGION` 类变量应部署前人工核对 **[INFO]**
- `firebase.json`：Firestore `location: asia-southeast1` 正确，functions 字段无 region 属性
- 未发现任何 `constants.js` / `config.js` 类常量文件

## 运行时风险评估

| # | 风险 | 评级 | 说明 |
|---|---|---|---|
| 1 | v1 函数 region 变更不迁移旧实例 | HIGH | Firebase v1 把 region 当作函数身份，必须手动 `functions:delete --region asia-east1` |
| 2 | **Firestore 触发器双 region 并存** | **CRITICAL**（高于 dev 原评级） | onNewApplication / onApplicationStatusChange / onMonthlyReportGenerated / onCheckinTimeout 会双触发；押金相关触发器双跑可能造成资金错账。**reviewer 建议部署窗口从 5 分钟收紧到 < 2 分钟** |
| 3 | Pub/Sub 定时任务双跑 | HIGH | sendPreMeetingReminder / generateMonthlyReports / expireApplications / openCheckinWindow 并存期间 cron 会跑两次。建议避开整点部署 |
| 4 | depositPaymentCallback webhook URL 变更 | MEDIUM | MVP D3 未启用支付，暂缓；DEPLOY-1 Backlog 已覆盖 |
| 5 | 客户端发版灰度 | LOW (MVP) | MVP 未发版可直接部署 + 立即删除旧实例 |

## 部署 Checklist

**T-0 部署前**
- 核对 `functions/.env` 无残留 `FUNCTIONS_REGION=asia-east1` 变量
- 避开整点/凌晨定时任务触发时刻

**T+0 部署**
- `firebase deploy --only functions`
- 冒烟：Flutter debug 调用 `applyToPost` 或 `submitCheckin` 任一 callable，验证 200
- Firebase Console 确认 asia-southeast1 出现 21 个函数

**T+2min 强制清理旧 region**
```
firebase functions:delete \
  registerFcmToken onNewApplication onApplicationStatusChange sendPreMeetingReminder onMonthlyReportGenerated \
  parseVoicePost generateDescription generateIcebreakers generateRecapCard generateMonthlyReports \
  freezeDeposit depositPaymentCallback refundDeposit \
  applyToPost acceptApplication rejectApplication expireApplications submitReview \
  openCheckinWindow submitCheckin onCheckinTimeout \
  --region asia-east1 --force
```
- Console 确认 asia-east1 下 0 个函数

**T+10min 观察**
- Cloud Logs 无 "Function not found" / region mismatch
- FCM 推送正常单次投递

**启用支付前（DEPLOY-1）**
- 微信支付 / 支付宝后台 webhook URL 更新为 `asia-southeast1-<project>.cloudfunctions.net/depositPaymentCallback`

## 结论

- 代码覆盖：21 functions + 1 客户端运行时常量 + 2 Dartdoc 注释 = 24 处，全部核对无残留
- 修复策略：dev 正确识别 checkin/review 共享 provider，最小化改动
- 运行时警告：dev 的部署警告全部准确；reviewer 独立收紧了 Firestore 触发器窗口要求
- **判定 [OK]**，可推进部署
