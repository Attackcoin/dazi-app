# test-mvp-journeys - 进度

## 2026-04-09

- 收到 phase 3 #2 任务：E2E 骨架（与 T1a 并行，不阻塞）
- 添加 `integration_test` dev 依赖 + pub get
- 新建 `client/integration_test/helpers/emulator_setup.dart`（boot + signOut）
- 新建 `client/integration_test/helpers/test_fixtures.dart`（3 个测试用户 + seed + reset）
- 新建 J0..J4 journey skeleton（全部 skip: true 留到执行阶段打开）
- `flutter analyze integration_test/` 0 issues
- 单元测试维持 28/28 PASS

**阻塞**：T1a firebase_options 占位 + 无连接设备 —— skeleton 完成，待 T1a 完成
及用户提供 Android AVD / 真机后继续执行阶段。

状态：**骨架完成，待执行阶段。**

## 2026-04-10

### [E2E-TEST] J0 PASS（web/chrome 走 flutter drive）

**结果**：`00:24 +3: All tests passed!`

**环境**：
- 设备：Chrome 146.0.7680.178（`flutter devices` 确认）
- Firebase emulators：用户本地已启动（Auth 9099 / Firestore 8080 / Hub 4400 均 200）
- `flutter analyze integration_test/` → 0 issues

**关键决策（写入 findings 阻塞解除）**：
1. 原尝试 `flutter test -d chrome integration_test/journey_smoke_test.dart` 失败，返回
   "Web devices are not supported for integration tests yet" —— flutter 官方规定 web 必须
   走 `flutter drive` + chromedriver，不能用 `flutter test`。
2. 发现 `client/test_driver/integration_test.dart` 已存在（之前 e2e-tester 已搭好 driver 入口）。
3. 环境缺 chromedriver：从 Chrome for Testing 下载 `146.0.7680.165/win64/chromedriver.zip`
   解压到 `C:\Users\CRISP\bin\chromedriver.exe`，后台启动 `chromedriver --port=4444`。
4. 最终命令（J0..J4 执行阶段都用这条）：
   ```
   cd client && flutter drive \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/journey_smoke_test.dart \
     -d chrome --browser-name=chrome
   ```

**日志噪音说明**：
- setUpAll 阶段连续打印多条 `StateError: Bad state: No element`（来自
  flutter_test `handlePointerEvent` → `firstWhere`），是 flutter web integration_test
  binding 对启动时鼠标事件的已知处理缺陷，不影响用例判定。若将来 J1-J4 因此被误判，
  需要显式 `tester.binding.defaultTestTimeout` 或忽略预热期指针事件。
- `WARNING: You are using the Auth Emulator` —— 预期输出，证明 emulator 已接入。

**J0 断言命中**：
`journey_smoke_test.dart:34` 的 `hasLoginCta || hasHomeCta` 在 `pumpAndSettle(5s)`
后为 true，即 app 成功从 splash 跳到登录页或首页。冒烟通过。

**改动的文件**：无（J0 skeleton 本就没 skip，且其余 J1-J4 的 skip 按任务要求不动）。

**下一步**：等 team-lead 下发 J1 短信验证码 helper + locator 精调任务。届时 chromedriver
已装好、drive 命令已验证，可直接复用。

## 2026-04-10 · J1 执行

### Setup 完成
- 新增 `client/integration_test/helpers/sms_code_helper.dart`（fetchLatestSmsCode via http GET /emulator/v1/projects/{p}/verificationCodes，按 phoneNumber 过滤取末尾最新，StateError/Exception 边界）
- pubspec.yaml dev_dependencies 加 `http: ^1.2.2`（仅测试用，未改生产代码）
- `journey_login_test.dart` 去 skip，加 polling（10 次 × 500ms）读 code，projectId 从 DefaultFirebaseOptions 取（dazi-dev）
- `flutter analyze integration_test/` → 0 issues
- chromedriver :4444 已起
- Auth emulator :9099 连通，`/verificationCodes` 端点返回空列表正常

### Strike 1：FAIL — resetFirestore permission-denied
- 错误：`[cloud_firestore/permission-denied] false for 'list' @ L15`（firestore.rules L15）
- 根因：J1 开头 `resetFirestore()` 在未登录态读 posts 集合，rules 拒绝；J0 没调此函数所以无事
- 下次尝试：J1 不需要重置 Firestore（测的是登录 UI），移除 `resetFirestore()` 调用

### Strike 2：PASS
- 移除 `resetFirestore()` 调用后重跑
- 结果：`00:52 +3: All tests passed!`
- 流程跑通：splash → login 页 → enterText 手机号 → 勾协议 Checkbox → 点"获取验证码" → polling fetchLatestSmsCode(dazi-dev, +8613800000001) 拿到 code → enterText 验证码 → 自动 submit（满 6 位触发）→ 登录态建立 → 不再显示"获取验证码"文案（断言通过）
- 日志提示 "Failed to initialize reCAPTCHA Enterprise config. Triggering the reCAPTCHA v2 verification." —— Auth emulator 下预期行为，不影响
- chromedriver 已 kill

### 改动文件清单
- `client/pubspec.yaml`（+2 行：http dev_dep）
- `client/integration_test/helpers/sms_code_helper.dart`（新文件，~55 行）
- `client/integration_test/journey_login_test.dart`
  - import firebase_options + sms_code_helper（L15-23）
  - 注释掉 resetFirestore 并说明原因（L36-38）
  - 用 polling 读真实 code 替换硬编码 '123456'（L55-73）
  - 去掉 `skip: true`（L90）

### 关键选择器
- 手机号输入：`find.byType(TextField).first`（登录页只有一个 TextField）
- 协议勾选：`find.byType(Checkbox)`
- 发码按钮：`find.widgetWithText(ElevatedButton, '获取验证码')`
- 验证码输入：`find.byType(TextField).first`（验证页也只有一个 TextField）
- 验证码自动 submit（满 6 位），所以 `find.widgetWithText(ElevatedButton, '验证并登录')` 作为保险 tap
- 登录成功断言：`find.text('获取验证码').evaluate().isEmpty`（已离开登录页）

### 耗时
- flutter drive 端到端：约 52s（含冷启动 66s 编译 Chrome 调试服务）
- 纯测试 run：1s（+1）到 52s（+2）= 51s

### 下一步
- J1 基线稳定，可继续 J2（post_create）。J2 需要登录态 → 走 `signInAndSeed(kTestUserAlice)` 的 email/password 快速通道（test_fixtures 已实现）而不是重复 phone flow。

## 2026-04-10 · J2 PASS

J2 发帖 journey 已打通（flutter drive ... journey_post_create_test.dart -d chrome → `00:51 +3: All tests passed!`，约 51s）。

### 前置发现
- `test_fixtures.dart` 已有 `signInAndSeed(TestUser)`（J1 汇报说的"已实现"属实）：走 email/password 在 Auth emulator 注册（或复用）+ 写完整 users/{uid} doc（27 字段 stub，以 city 非空保证 onboarding redirect 不触发）。**未新建 helper**。
- 发帖入口：`HomeShell` 的 `FloatingActionButton.extended`，label "即刻出发"，icon `Icons.bolt`，onPressed `context.push('/post/create')`
- 发帖页 `CreatePostScreen`：分类 Wrap（6 项 GestureDetector："吃喝" 等）→ 标题 TextField（maxLength 30）→ 图片 picker（跳过）→ **时间 InkWell "选择活动时间"**（触发原生 `showDatePicker` + `showTimePicker`，initialDate=now+1d，initialTime=19:00）→ 地点 TextField → 人数 Row（默认 4 OK）→ 描述 TextField → bottomNavigationBar `ElevatedButton "发布"`
- `PostDraft.validate()` 必填：category / title / time (>now) / locationName / totalSlots>=2
- app 未配 `localizationsDelegates` → Material picker 按钮是英文 "OK"

### Strike 1：FAIL — resetFirestore 里清理 applications 被 rules 拒
- 错误：`[cloud_firestore/permission-denied] Property applicantId is undefined on object. for 'list' @ L23`
- 根因：`resetFirestore()` for 循环清 `['posts','applications','matches','reviews']`，即使已登录 Alice，`list applications` 仍要求 `where applicantId == request.auth.uid` 条件，无条件 list 被 rules L23 拒
- 下次尝试：J2 用唯一标题 `周末咖啡探店` 查 Firestore 区分本次新帖，不依赖全表清空 → 直接去掉 resetFirestore 调用（test_fixtures.dart 本身不动，避免影响其他 journey 的假设；只在 J2 测试里规避）

### Strike 2：PASS
- 移除 resetFirestore 后重跑
- 流程：signInAndSeed(Alice) → app.main → splash → 自动 redirect 到 `/`（Alice city 已填）→ 点 FAB Icons.bolt → 发帖页 → tap "吃喝" → enterText "周末咖啡探店" → tap "选择活动时间" → tap "OK"（DatePicker）→ tap "OK"（TimePicker）→ enterText 地点 → ensureVisible + tap "发布" → pumpAndSettle 8s → 直查 Firestore `posts where title==kTitle` → 命中 1 条，断言 userId/category/status/location.name 全部通过
- 已知噪音：`PostCard` Column RenderFlex overflow 15px（pushReplacement 到详情页后首页列表重建了一下 PostCard 渲染）—— 测试结束后作为 warning 打印，不是 failed test。属生产 UI 小问题（`lib/presentation/features/home/widgets/post_card.dart:31:16` 的 Column），建议后续让 frontend-dev 修
- chromedriver 已 kill

### 改动文件清单
- `client/integration_test/journey_post_create_test.dart`（整体重写：
  - 新的 import `cloud_firestore`（L10）
  - 去 `skip: true`
  - setUp 流程：signInAndSeed 先（L34）
  - FAB 选择器 `find.byIcon(Icons.bolt)`（L41）
  - 分类 `find.text('吃喝')` tap（L46）
  - title `find.byType(TextField).at(0)` + kTitle（L51-54）
  - 时间 flow: tap "选择活动时间" → "OK" → "OK"（L59-64）
  - location `find.byType(TextField).at(1)`（L67-69）
  - 发布 `find.widgetWithText(ElevatedButton, '发布')` + ensureVisible（L72-75）
  - Firestore 直查断言（L80-95）
- **未改**：test_fixtures.dart / 生产代码 / pubspec.yaml

### 关键选择器
- 发帖入口：`find.byIcon(Icons.bolt)`（HomeShell FAB.extended）
- 分类：`find.text('吃喝')`（其它：运动/文艺/旅行/学习/游戏）
- 标题输入：`find.byType(TextField).at(0)`
- 时间触发：`find.text('选择活动时间')`
- 日期/时间 picker 确认：`find.text('OK')`（app 未加 localizationsDelegates，按钮文字英文）
- 地点输入：`find.byType(TextField).at(1)`
- 发布按钮：`find.widgetWithText(ElevatedButton, '发布')`（bottomNavigationBar 内，需 ensureVisible）

### 断言策略
- **纯 Firestore 直查**（不依赖详情页 UI 稳定性）
- 用唯一标题做 where 过滤，避免与其他 journey/遗留数据冲突
- 校验 userId / category / status / location.name 4 个关键字段

### 耗时
- flutter drive 端到端：约 51s
- 纯测试 run：+1 到 +2 约 50s（splash→login redirect→home→发帖→提交→断言）

### 下一步
- J2 基线稳定，可继续 J3（feed_apply）—— 其中 "切换登录账号" 需 `signOutIfAny` + `signInAndSeed(kTestUserBob)`，seed 一条 Alice 的帖（直接 Firestore 写 posts doc，绕 UI）再用 Bob 申请
- **Backlog 提醒 team-lead**：resetFirestore 对 applications/matches/reviews 集合在已登录态下仍因 rules require where 而失败，考虑 (a) 让 helper 按 currentUser.uid 过滤分集合删，或 (b) 用 Firebase Admin REST (`DELETE /emulator/v1/projects/{p}/databases/(default)/documents/applications`) 绕 rules 一键清。推荐 (b) —— 一行活儿，KP 候选
- **Backlog 给 frontend-dev**：PostCard Column RenderFlex overflow 15px (`home/widgets/post_card.dart:31:16`)，小瑕疵，非 blocker

## 2026-04-10 · J3 BLOCKED — Functions emulator 未运行

J3 feed+申请 journey **BLOCKED**，非测试代码问题：UI 流程完全走通（首页→点卡片→详情→立即申请→ApplySheet→确认申请），但 Cloud Function `applyToPost` 不可达，applications 集合无写入。

### Seed 路径
- **Firestore 直写**（方案 A）：`signInAndSeed(Alice)` → `FirebaseFirestore.collection('posts').add({...})` → `signOutIfAny()`。未走 UI 发帖（J2 已验证过，省时）。
- post 字段：category='吃喝', title=`J3探店_<ts>`（唯一标题幂等），status='open', totalSlots=4, acceptedGender={male:0,female:0}, location.city='上海'（与 Bob 同城，feedProvider 按 city 过滤）

### 切换账号
- `signOutIfAny()`（test_fixtures 已有）→ `signInAndSeed(kTestUserBob)`。未新建 switchUser helper。app.main() 启动，Bob 的 city='上海' → onboarding 跳过 → 直接进首页，feedProvider 取到 Alice 新 post。

### UI 流程（**全部 tap 成功**）
1. `find.text(kTitle)` —— 命中（polling 10×500ms 等 stream 推送完成）
2. tap 卡片 → 详情页（go_router `/post/{id}`）
3. `find.widgetWithText(ElevatedButton, '立即申请')` —— 命中并 tap
4. `find.widgetWithText(ElevatedButton, '确认申请')` —— ApplySheet 弹出，命中并 tap
5. pumpAndSettle 5s

### Strike 1：FAIL — applications 查询为空（10×500ms polling 后）
- 断言 `where postId==<id> and applicantId==bob.uid` 返回 0 docs
- 日志里**没有任何** Function 调用报错/SnackBar/权限错误 —— 纯静默无写入
- **根因**：**Functions emulator 没在运行**。查 hub：
  ```
  curl http://127.0.0.1:4400/emulators
  ```
  返回的 emulators 只有：`hub / ui / logging / auth / firestore`。**缺 functions、storage、database**。直接拨号 `127.0.0.1:5001 / 9199 / 9000` 都 `Connection refused`（curl exit 7）。
- `applyToPost` 是 `https.onCall` Cloud Function（`functions/src/applications.js:14-92`），客户端通过 `FirebaseFunctions.instanceFor('asia-southeast1').httpsCallable('applyToPost')` 调用（`client/lib/data/repositories/application_repository.dart:33-41`）。Functions emulator 未起 → callable 报错 → ApplySheet._submit catch 住 → 只显示 SnackBar，不写 applications。
- 日志里只 6 条 PostCard RenderFlex overflow（Backlog UI-BL-1，非阻塞），外加我的断言失败。

### 约束下的不可行方案
- **不能改生产代码** → 不能把 applyToPost 改成客户端直写
- **不能启动 emulator**（用户本地在跑，任务明示"不要启动"）
- 绕过 UI 直接在测试里 `applications.add({...})` 能让断言过，但完全失去 J3 价值（跳过 _ApplicantButtons + ApplySheet + Cloud Function 链路），背离"真实申请流程"

### 请求 team-lead 决策
**请确认并启动 Functions emulator（以及 storage / database，为 J4 做铺垫）**：
```
firebase emulators:start --only auth,firestore,functions,storage,database
```
或在当前 emulator 进程旁另起：
```
firebase emulators:start --only functions
```
启动后 J3 即可解除阻塞，测试代码无需再动 —— 直接重跑 `flutter drive --target=integration_test/journey_feed_apply_test.dart -d chrome` 预期绿。

### 改动文件
- `client/integration_test/journey_feed_apply_test.dart`（整体重写，~140 行）
  - import cloud_firestore + flutter/material（L10-14）
  - 去 `skip: true`
  - 唯一标题幂等 `J3探店_${ts}`（L26）
  - Alice signInAndSeed → 直写 posts doc（L31-60） → signOutIfAny
  - Bob signInAndSeed + app.main（L67-73）
  - 首页 polling find kTitle（L82-88）
  - tap card → 详情 → "立即申请" → "确认申请"（L93-115）
  - Firestore polling `where postId==... and applicantId==bob.uid`（L122-142）
- **未改**：test_fixtures.dart / emulator_setup.dart / 生产代码

### 关键选择器（验证可用，UI 层无问题）
- 首页卡片：`find.text(kTitle)` （polling 10×500ms 等 Firestore stream）
- 详情页主按钮：`find.widgetWithText(ElevatedButton, '立即申请')`（见 `post_detail_screen.dart:276 _ApplicantButtons`，post.status=open 且未满时 label='立即申请'）
- ApplySheet 确认：`find.widgetWithText(ElevatedButton, '确认申请')`（见 `apply_sheet.dart:142`，非 full 时 label='确认申请'）

### 3-Strike 记录
- Strike 1：applications 查询空 → 根因定位到 Functions emulator 未运行 → 上报

### 耗时
- 本轮 flutter drive 端到端：约 54s（编译 58s + 测试运行 54s）
- 分析 + 写测试 + 诊断：约 8 分钟

### 下一步
- **阻塞在**：Functions emulator 未运行
- team-lead 启动 functions emulator 后，我直接重跑即可（测试代码已就绪）
- J4 同样会依赖 functions（可能还依赖 storage for avatar），建议一并启动
