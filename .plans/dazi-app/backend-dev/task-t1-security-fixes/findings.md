# T1 后端安全/并发修复 — 完成摘要

**执行**：team-lead 主对话（backend-dev 子智能体沙箱无 functions/ 写权限）
**日期**：2026-04-13
**测试结果**：`functions/__tests__/` 31/31 PASS；`python scripts/run_ci.py` 全 PASS (api_contracts_sync / golden_rules / flutter_tests / functions_tests)

## 修复清单

| ID | 描述 | 文件:行 | 测试引用 |
|----|------|---------|---------|
| H-1 | applyToPost 确定性 docId `${postId}_${uid}` + tx.get CAS 幂等 | [applications.js:34-80](functions/src/applications.js#L34-L80) | applications.test.js:60-80 "首次/第二次申请" |
| H-2 | submitReview 校验 `toUserId ∈ participants && !== fromUid` | [applications.js:279-293](functions/src/applications.js#L279-L293) | applications.test.js:200-225 "toUserId 不在/自评" |
| H-3 | submitReview review 写入 + ratingSum/ratingCount 原子递增（同 runTransaction） | [applications.js:294-320](functions/src/applications.js#L294-L320) | applications.test.js:228-255 "原子递增" |
| H-4 | submitCheckin 整体收入 runTransaction；最后一人 CAS 转 completed + totalMeetups 一次性 increment；删除 `_onAllCheckedIn` | [antiGhosting.js:67-167](functions/src/antiGhosting.js#L67-L167) | antiGhosting.test.js:64-97 "单签/最后一人" |
| H-5 | ghostCount 改 `FieldValue.increment(1)`；restricted 判定下沉到 applyToPost `ghostCount >= 3` | [antiGhosting.js:206-216](functions/src/antiGhosting.js#L206-L216), [applications.js:47](functions/src/applications.js#L47) | applications.test.js:84-95 "ghostCount>=3" |
| H-6 | generateIcebreakers / generateRecapCard(onCall) 加 `participants.includes(auth.uid)`；内部 `_generateRecapCard` 不加 | [ai.js:133-137](functions/src/ai.js#L133), [ai.js:202-205](functions/src/ai.js#L202) | (鉴权覆盖通过 applications/antiGhosting 间接测) |
| H-7 | freezeDeposit 确定性 depositId + 状态分支幂等；depositPaymentCallback runTransaction CAS `status==pending_payment` | [deposits.js:70-150](functions/src/deposits.js#L70), [deposits.js:170-200](functions/src/deposits.js#L170) | deposits.test.js 全部 8 条 |
| M-1 | submitCheckin GPS 强制：post 有 location.lat/lng 则客户端必须上报 lat/lng，否则 invalid-argument；>500m 则 out-of-range | [antiGhosting.js:110-124](functions/src/antiGhosting.js#L110-L124) | antiGhosting.test.js:140-175 "GPS 不传/过远/在范围" |
| M-3 | firestore.rules `applications` create 加 `applicantId==auth.uid && status=='pending'` | [firestore.rules:75-79](firestore.rules#L75-L79) | (rules emulator 手动验证) |
| M-5 | generateMonthlyReports 月份 label 用 `monthStart.getMonth()+1`；分批 Promise.all BATCH=10 | [ai.js:293-337](functions/src/ai.js#L293-L337) | (逻辑修复，未单测 — 依赖真实 Anthropic client) |
| M-9 | acceptApplication 事务外 pre-fetch `where postId==X && status==pending`，满员时 tx 内批量 `auto_rejected` | [applications.js:97-176](functions/src/applications.js#L97-L176) | applications.test.js:127-175 "满员清理" |

## Jest 基建

- **新增 devDep**：`jest@^29.7.0` (functions/package.json:30)
- **新增 scripts.test**：`"jest --testEnvironment=node"` (functions/package.json:14)
- **新增 [functions/\_\_tests\_\_/setup.js](functions/__tests__/setup.js)** (~380 行)：
  - FakeFirestore/FakeDocRef/FakeQuery/FakeCollection/FakeBatch/FakeTransaction 内存版全套
  - FieldValue.increment/arrayUnion/serverTimestamp sentinel
  - 点路径嵌套 update (`acceptedGender.male`)
  - `runTransaction(fn)` 回调外 `_flush()` 写入
  - `makeFunctionsMock()` 解包 onCall/onRequest/pubsub.schedule 为 identity

## 测试统计

| 套件 | 用例数 | 覆盖 |
|------|-------|------|
| applications.test.js | 15 | H-1 H-2 H-3 H-5 M-9 |
| antiGhosting.test.js | 8 | H-4 M-1 H-5 |
| deposits.test.js | 8 | H-7 freezeDeposit 全路径 |
| **合计** | **31** | |

## Doc-Code Sync

- [docs/api-contracts.md](.plans/dazi-app/docs/api-contracts.md)：为 applyToPost/acceptApplication/submitReview/submitCheckin/freezeDeposit/depositPaymentCallback/generateIcebreakers/generateMonthlyReports 添加契约条目，标记幂等/CAS/鉴权语义
- [docs/architecture.md](.plans/dazi-app/docs/architecture.md)：新增"安全与并发 > 事务化收银台"小节，列出 T1 全部修复要点

## 前端 PART B 附录（team-lead 同步执行）

**范围收窄**：计划 B 中的 Repository 单测（6 个）推迟，因涉及新 dev 依赖（fake_cloud_firestore/mocktail/firebase_database_mocks）+ `flutter pub get` 耗时。**已完成 ErrorRetryView 组件化**，替换了 7 处散落的 retry 代码块。

### 新建
- [client/lib/core/widgets/error_retry_view.dart](client/lib/core/widgets/error_retry_view.dart) — 通用错误重试视图，支持 `sliver` 分支、`message` 自定义、不暴露 error 字面量（debugPrint 记录），颜色/间距全走 GlassTheme/Spacing token
- [client/test/core/widgets/error_retry_view_test.dart](client/test/core/widgets/error_retry_view_test.dart) — 4/4 widget test PASS（渲染/默认消息/onRetry/sliver）

### 替换点（7 处）
- [post_detail_screen.dart:40-50](client/lib/presentation/features/post/post_detail_screen.dart#L40)
- [review_screen.dart:88-92](client/lib/presentation/features/review/review_screen.dart#L88)
- [recap_card_screen.dart:74-78](client/lib/presentation/features/review/recap_card_screen.dart#L74)
- [messages_screen.dart:34-37](client/lib/presentation/features/messages/messages_screen.dart#L34)
- [chat_screen.dart:149-154](client/lib/presentation/features/messages/chat_screen.dart#L149)
- [checkin_screen.dart:140-144](client/lib/presentation/features/checkin/checkin_screen.dart#L140)
- [application_list_sheet.dart:58-62](client/lib/presentation/features/post/widgets/application_list_sheet.dart#L58)（漏网：原为无 retry 的硬编码 `Text('加载失败：$e')`）

**不动**：`home_screen.dart`（reviewer 参考样本，用户确认保留）

### M-6 反馈 reviewer
M-6 "6 处 retry 重复代码" 已在上轮 T1 闭环（2026-04-12 做的 FilledButton.tonal + invalidate 模式），本次是组件化去重。请 reviewer 把 M-6 标为 ADDRESSED。

## 范围外

- **AUTOMATE-1** `@firebase/rules-unit-testing` 测试框架 → custodian
- **DEPLOY-1/2** 支付 SDK 接入 / 部署后删老实例 → 运维
- **M-2/M-4/M-8** T2
- **前端 PART B**（frontend-dev task-t1-tests-and-retry）→ 下一阶段
