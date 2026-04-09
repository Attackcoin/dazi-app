# 搭子 App — Flutter 前端

## 环境要求

- Flutter SDK 3.27+（已验证 3.27.4）
- Dart 3.6+
- Android Studio（Android 模拟器）
- Xcode（iOS 调试，需 Mac）
- 一个 Firebase 项目（`dazi-dev` 已配置）

## 首次运行（必做）

### 1. 配置 Firebase

```bash
# 安装 FlutterFire CLI
dart pub global activate flutterfire_cli

# 登录 Firebase
firebase login

# 进入 client 目录
cd client

# 自动生成 firebase_options.dart（会覆盖占位文件）
flutterfire configure --project=dazi-dev
```

选择平台时勾选 **Android + iOS**。

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 运行

```bash
# 列出可用设备
flutter devices

# 运行到指定设备
flutter run -d <device_id>
```

## 架构

```
lib/
├── main.dart                    # 入口，初始化 Firebase
├── app.dart                     # MaterialApp.router
├── firebase_options.dart        # FlutterFire 自动生成（占位）
│
├── core/                        # 核心基础设施
│   ├── router/app_router.dart   # go_router 路由配置
│   └── theme/                   # 主题、颜色
│
├── data/                        # 数据层
│   ├── models/                  # 数据模型（Post, AppUser）
│   └── repositories/            # Firestore 仓库
│
└── presentation/features/       # UI 层
    ├── splash/                  # 启动页
    ├── auth/                    # 登录 / 验证码
    ├── home/                    # 广场 / 底部导航
    ├── post/                    # 帖子详情
    └── profile/                 # 个人主页
```

**状态管理**：Riverpod（`flutter_riverpod`）
**路由**：go_router
**后端**：Firebase Auth / Firestore / Storage / Functions / FCM

## 已完成页面

- ✅ Splash（启动页）
- ✅ Login（手机号登录）
- ✅ Phone Verify（验证码输入）
- ✅ Home（广场 - 分类筛选 + 帖子列表）
- ✅ Post Detail（帖子详情）
- ✅ Profile（个人主页）
- ✅ HomeShell（底部导航：广场/消息/我的 + 即刻出发浮动按钮）

## 待完成页面

- [ ] Onboarding（5 步注册引导）
- [ ] Create Post（发布搭子 - 表单 + 语音 AI）
- [ ] Messages（消息列表）
- [ ] Chat（聊天页）
- [ ] Check-in（签到页）
- [ ] Settings（各种设置子页）

## 开发命令

```bash
flutter run             # 热重载运行
flutter analyze         # 静态分析
flutter test            # 运行测试
flutter build apk       # Build Android
flutter build ios       # Build iOS (需 Mac)
```

## 常见问题

**Q: `firebase_options.dart` 报错？**
A: 必须先运行 `flutterfire configure`，否则占位值会导致 Firebase 初始化失败。

**Q: 无法连接 Firestore？**
A: 检查 `firestore.rules` 是否允许当前用户读取。修改后用
`firebase deploy --only firestore:rules` 部署。

**Q: 手机号登录收不到验证码？**
A: Firebase Phone Auth 在中国大陆需要额外配置 reCAPTCHA 和 APNs。
测试阶段可以在 Firebase Console → Authentication → Settings →
Phone numbers for testing 添加测试号码。
