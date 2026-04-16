# T3 — E2E 关键流程验证（T1 修复闭环）

**目标**：用 integration_test 覆盖 T1 修复的 H-1~H-7 + M-1/M-9 核心路径，给未来回归提供可执行基线。

**状态**：进行中（2026-04-14）
**前置**：T1 修复已 [OK]（reviewer verdict 2026-04-14）
**环境**：Flutter web + chromedriver + firebase emulators（KP-2/KP-5 已记录）

---

## 1. 现状

### 已有 journey（J0-J4）
| ID | 流程 | 最后验证 | 覆盖的 T1 修复 |
|----|------|---------|---------------|
| J0 | 冒烟启动 | PASS 2026-04-10 | — |
| J1 | 手机号登录 | PASS 2026-04-10 | — |
| J2 | 发帖（Alice UI） | 未运行 | 帖子 rules 字段白名单（task-security-fixes H-2） |
| J3 | 浏览+申请（Bob UI） | 未运行 | **H-1 applyToPost CAS**、**H-5 ghostCount restricted** |
| J4 | 主页（自己/他人） | 未运行 | — |

### 待新增 journey（J5-J8）
| ID | 流程 | 验证目标 |
|----|------|---------|
| J5 | acceptApplication + 满员 auto_reject | **M-9** 满员批量拒绝、match 创建事务、H-1 状态流转 |
| J6 | submitCheckin（双人 + GPS 强制） | **H-4** CAS 最后一人 completed、**M-1** GPS 强制 |
| J7 | submitReview（双向 + ratingSum/Count） | **H-2** toUserId 校验、**H-3** 事务化 |
| J8 | deposits freeze + HMAC callback | **H-7** 确定性 id + CAS + callback 事务 |

J8 需模拟支付回调 HMAC 签名，复杂度 >> J5-J7，本轮先跳过作为 backlog。

---

## 2. 范围（本轮交付）

### Phase A — 回归运行 J0-J4（0.5 天）
1. 启动 emulators + chromedriver（`scripts/` 或手动）
2. 逐个跑 J0 → J4，记录 PASS/FAIL
3. 任何 FAIL → 先修 journey 再往下
4. 基线建立后续 PR 必跑

### Phase B — 新增 J5 acceptApplication（0.5 天）
- 文件：`integration_test/journey_accept_application_test.dart`
- 策略：**不走 UI**，直接用 `FirebaseFunctions.instance.httpsCallable('acceptApplication')` 调后端 + Firestore 断言
- 理由：UI 层 `application_list_sheet.dart` 测试价值低，真正的 M-9 逻辑在 Cloud Function 事务
- 步骤：
  1. Alice 发帖（`totalSlots: 2`，即 owner + 1 个人就满）
  2. Bob + Carol 双双 apply（直接 callable `applyToPost`）
  3. Alice 登录 → callable `acceptApplication({applicationId: bobAppId})`
  4. 断言：
     - `applications/{bobAppId}.status == 'accepted'`
     - `applications/{carolAppId}.status == 'auto_rejected'`（M-9）
     - `posts/{postId}.status == 'full'`
     - `matches` 有一条 `participants: [alice.uid, bob.uid]` 的记录
     - match 的 `postTitle`/`postCategory`/`participantInfo` 冗余字段正确（冗余写入验证）

### Phase C — 新增 J6 submitCheckin（0.5 天）
- 文件：`integration_test/journey_checkin_test.dart`
- 策略：直接 callable，跳过 UI
- 前置：J5 的 match 已存在，需手动把 `status='confirmed'` 的 match 的 `meetTime` 往前调、`checkinWindowOpen=true`
  - 不走 `openCheckinWindow` pubsub（pubsub emulator 默认不自动触发）
  - 直接 admin update
- 步骤：
  1. 复用 J5 的 match 或用 fixture 新建一个（post 带 location.lat/lng）
  2. Bob callable `submitCheckin({matchId, lat, lng})` —— **先测 GPS 缺失被拒**（M-1）
  3. Bob 正确 lat/lng 提交 → `checkedIn: [bob]`
  4. Alice 提交 → `checkedIn: [alice, bob]`、`status: completed`、`users/*/totalMeetups +1`（H-4 CAS）
  5. 断言 post.status='done'

### Phase D — 新增 J7 submitReview（0.5 天）
- 文件：`integration_test/journey_review_test.dart`
- 策略：直接 callable
- 步骤：
  1. 复用 J6 的 completed match
  2. Bob callable `submitReview({matchId, toUserId: alice.uid, rating: 5, text: ''})`
     - **先测 toUserId == self** 应被拒（H-2）
     - **先测 toUserId == 非 participants** 应被拒（H-2）
  3. 正常提交 → 断言：
     - `reviews/{matchId}_{bob.uid}_{alice.uid}` 存在
     - `users/alice.uid.ratingSum += 5`, `ratingCount += 1`（H-3 事务原子）
  4. Bob 重复提交 → 应被拒（幂等）

---

## 3. 非目标（延后）

- J8 deposits callback HMAC — 需要假支付通道，复杂度高
- `openCheckinWindow` pubsub 触发器本身 — firestore-emulator 不跑 scheduled；靠后端单测
- `onNewApplication` FCM 通知触发 — FCM emulator 不发真推送

---

## 4. 执行要点

### 4.1 运行命令（参考 KP-2/KP-5）
```bash
# 终端 1：firebase emulators
cd C:/Users/CRISP/OneDrive/文档/dazi-app
firebase emulators:start --only auth,firestore,functions,storage,database

# 终端 2：chromedriver
C:/Users/CRISP/bin/chromedriver.exe --port=4444 &

# 终端 3：flutter drive 跑单个 journey
cd client
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/journey_accept_application_test.dart \
  -d chrome --browser-name=chrome \
  --dart-define=USE_EMULATOR=true
```

### 4.2 Helper 补充需求
- `test_fixtures.dart` 加 `callFunction(name, data)` wrapper（带 region `asia-southeast1`）
- 可选：加 `resetFirestoreAdmin()` 走 emulator REST（KP-4 长期方案）—— 本轮先用唯一后缀策略

### 4.3 断言稳定性
- 所有 Firestore 断言用 polling（10 × 500ms），因为 Cloud Function 往返异步
- 用 postId/matchId 精确过滤，避免遗留数据干扰

---

## 5. 风险

| 风险 | 缓解 |
|------|------|
| emulator functions 冷启动慢 | setUpAll warm-up：调一次 `parseVoicePost({text:'x'})` 忽略结果 |
| pubsub 触发器不跑 | 测试中手动 admin update 模拟 |
| 测试数据污染后续 run | 唯一 title 后缀 `_${millis}`，断言用精确过滤 |
| chromedriver 版本错配 | KP-2 已记录 146.0.7680.165；chrome 升级后需同步升 driver |

---

## 6. 交付物

- [x] Phase A：J0-J4 全部 PASS（2026-04-15，commit 6f025eb）
- [x] Phase B：journey_accept_application_test.dart 写入 + PASS（2026-04-16）
- [x] Phase C：journey_checkin_test.dart 写入 + PASS（2026-04-16）
- [x] Phase D：journey_review_test.dart 写入 + PASS（2026-04-16，修复 signOut 后读 users 的 permission-denied）
- [x] findings.md 汇总每 journey 验证的 T1 修复 ID
- [ ] Known Pitfalls 追加（如有新发现）
