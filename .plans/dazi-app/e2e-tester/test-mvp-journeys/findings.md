# test-mvp-journeys - E2E 骨架搭建

> 阶段 3 #2：E2E 测试骨架 + Journey 设计（未执行态）。
> 完成日期：2026-04-09

## 范围

搭建 integration_test 目录结构、emulator 接入 helper、MVP 5 个 journey 的 skeleton，
使 `flutter analyze integration_test/` 全绿。**实际运行被 T1a 与设备可用性阻塞**，
skeleton 中使用 `skip: true` 避免 CI 红。

## 交付物

### 目录
```
client/integration_test/
├── helpers/
│   ├── emulator_setup.dart          # bootTestFirebase() + signOutIfAny()
│   └── test_fixtures.dart           # 预置 Alice/Bob/Carol 3 个测试用户 + seed 工具
├── journey_smoke_test.dart          # J0 冒烟 —— app 启动看 splash/login
├── journey_login_test.dart          # J1 手机号登录 → onboarding
├── journey_post_create_test.dart    # J2 发帖 → 详情可见
├── journey_feed_apply_test.dart     # J3 浏览 + 申请
└── journey_profile_test.dart        # J4 自己 vs 他人主页
```

### 依赖
- `client/pubspec.yaml` dev_dependencies 新增 `integration_test: {sdk: flutter}`
- `flutter pub get` 已跑过，lock 更新

### Emulator Helper
`helpers/emulator_setup.dart` 的 `bootTestFirebase()`：
- `Firebase.initializeApp` with `DefaultFirebaseOptions.currentPlatform`
- `useAuthEmulator('127.0.0.1', 9099)`
- `useFirestoreEmulator('127.0.0.1', 8080)` + `persistenceEnabled: false, sslEnabled: false`
- `FirebaseFunctions.instanceFor(region: 'asia-southeast1').useFunctionsEmulator(...)` —— 区域与 T1b 修复后的后端一致
- `useStorageEmulator('127.0.0.1', 9199)`
- `useDatabaseEmulator('127.0.0.1', 9000)`
- 幂等（`_initialized` 守卫）

端口与 `firebase.json` `emulators` 块一致。

### Fixtures
3 个 const 测试用户：`kTestUserAlice` (uid=test-alice, +8613800000001, 上海) /
`kTestUserBob` (test-bob, 上海) / `kTestUserCarol` (test-carol, 北京)。
`resetFirestore()` 清空 posts/applications/matches/reviews，`seedUser(u)` 写完整
27 字段的 users/{uid} doc。

### Journeys（全部 skip: true，等 T1a + 设备）

| ID | 流程 | 依赖 |
|----|------|------|
| J0 | 冒烟 —— app 启动后进入 splash 或登录页 | 仅 T1a |
| J1 | 手机号输入 → emulator 的 123456 → onboarding 页 | T1a + widget 定位器精确化 |
| J2 | Alice 发帖 → 填表 → 提交 → 详情页显示新标题 | J1 登录能打通 |
| J3 | Bob 浏览 Alice 的帖 → 点卡片 → 申请 → 验证 Firestore applications 集合 | J1 + 切换登录账号 |
| J4 | 自己主页（编辑/设置按钮） + 他人主页（更多菜单 + 无编辑） | J1 + go_router deep link |

## 阻塞项

1. ~~**T1a firebase_options.dart 占位**~~ → **已解除** (2026-04-09) firebase_options.dart 已真实生成
2. ~~**无 Android/iOS 连接设备**~~ → **已解除** (2026-04-10) 改走 web + chromedriver 路线：
   - `flutter test -d chrome` 对 integration_test **不支持**，web 必须用 `flutter drive`
   - 已下载 chromedriver 146.0.7680.165 到 `C:\Users\CRISP\bin\chromedriver.exe`
   - 运行命令：`chromedriver --port=4444 &` 后 `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<X>.dart -d chrome --browser-name=chrome`
   - J0 已用此方案打通（见 progress.md 2026-04-10）
3. **emulator 短信验证码获取方式待定** —— Firebase Auth emulator 不会真发短信，
   code 通过 REST `/emulator/v1/projects/{p}/verificationCodes` 拉取。J1 的 widget
   流程只完成到 UI 层，code 获取需补 helper。**仍待处理，是 J1 的先决条件。**

## 已验证基准（J0）

- Chrome 146 + chromedriver 4444 + firebase emulators (auth/firestore/functions/storage/database) 全栈可跑
- `bootTestFirebase()` 在 web 环境能正确接入 Auth emulator（日志印出 `Using previously configured Auth emulator at http://127.0.0.1:9099`）
- 已知噪音：setUpAll 阶段 `StateError: Bad state: No element` 来自 flutter_test web binding 对启动期指针事件的处理，不影响用例判定，J1-J4 可忽略

## 验证现状

- `flutter analyze integration_test/` → **0 issues**
- `flutter test integration_test/journey_smoke_test.dart` → **No supported devices**
  （分析通过但需设备）
- 单元测试仍然 28/28 PASS

## 下一步（待 T1a 和设备就绪）

1. 运行 `flutterfire configure` 生成真实 firebase_options（用户已同时在做）
2. 启动 Android emulator 或 web target
3. 启动 `firebase emulators:start --only auth,firestore,functions,storage,database`
4. 先把 J0 冒烟打通，作为 widget 定位器的 "已知可用" 基准
5. 逐个取消 J1..J4 的 skip，先打通登录 → 其他自动可用
6. 打通后补 emulator REST 短信验证码 helper
echo ok

## 2026-04-10 · J1 PASS

J1 手机号登录 journey 已打通（flutter drive ... journey_login_test.dart -d chrome → +3 All tests passed!，52s）。

### 解除的阻塞
- ~~**emulator 短信验证码获取方式**~~ → **已解除**：新增 `helpers/sms_code_helper.dart`，通过 `GET http://127.0.0.1:9099/emulator/v1/projects/{projectId}/verificationCodes` 读取，按 phoneNumber 过滤取列表末尾最新一条。projectId 从 `DefaultFirebaseOptions.currentPlatform.projectId`（dazi-dev）拿。加 10 × 500ms polling 规避 sendPhoneCode → emulator 写入的时序差。
- 依赖：`client/pubspec.yaml` dev_dependencies 加了 `http: ^1.2.2`（仅 integration_test 使用，未触碰生产依赖）

### 坑位收集
- **KP-candidate**: J1 开头不能调 `resetFirestore()` —— 未登录态下 firestore.rules L15 拒绝 list posts。后续 J2-J4 应在 `signInAndSeed(...)` **之后**再调 resetFirestore，或在 fixtures 里用 Admin SDK 绕过 rules。建议：修改 `test_fixtures.dart` 让 resetFirestore 要求先登录或加 warning 注释。
- **reCAPTCHA 日志噪音**: Chrome web 下用 phone auth 会打印 "Failed to initialize reCAPTCHA Enterprise config. Triggering the reCAPTCHA v2 verification." —— Auth emulator 不验 reCAPTCHA，忽略即可。

### 复用物
- `sms_code_helper.fetchLatestSmsCode(projectId, phone)` 可供任何其他手机登录 journey 复用
- 登录页选择器已验证稳定：`TextField.first` / `Checkbox` / `ElevatedButton + 文字` 耐久度 OK
