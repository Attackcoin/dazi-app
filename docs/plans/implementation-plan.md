# 搭子 App 实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 用 FlutterFlow + Firebase 构建国内搭子社交 App，从环境搭建到上架发布的完整操作指南。

**Architecture:** FlutterFlow 可视化构建前端，Firebase 提供后端服务（Auth/Firestore/Functions/FCM/Storage），第三方集成包括阿里云实人认证、微信/支付宝支付、Claude API、Algolia搜索。

**Tech Stack:** FlutterFlow · Firebase · Claude Haiku API · 阿里云实人认证 · 微信支付/支付宝 · Algolia · Google Maps API

---

## 阶段一：环境搭建（Day 1）

### Task 1：注册 Firebase 项目（三套环境）

**Step 1: 注册 Firebase 账号**
前往 https://firebase.google.com，用 Google 账号登录

**Step 2: 创建三个项目**
点击「Add project」，依次创建：
- `dazi-dev`（开发测试用）
- `dazi-staging`（预发布测试用）
- `dazi-prod`（正式生产用）

**Step 3: 每个项目开启以下服务**
在 Firebase Console 左侧菜单依次点击开启：
- Authentication → Sign-in method → 开启「手机号」「Google」「Apple」
- Firestore Database → Create database → 选「Start in test mode」
- Storage → Get started
- Functions → Get started（需要升级到 Blaze 付费计划，按用量计费）
- Realtime Database → Create database（用于聊天消息）

**Step 4: 验证**
三个项目均显示绿色状态，所有服务已启用

**Step 5: 记录重要信息**
保存每个项目的 `Project ID`，后续配置需要用到

---

### Task 2：注册 FlutterFlow 并连接 Firebase

**Step 1: 注册 FlutterFlow**
前往 https://flutterflow.io，注册账号（建议用同一个 Google 账号）

**Step 2: 升级到 Pro 计划**
Settings → Billing → 升级 Pro（$30/月），发布 App 必须

**Step 3: 新建项目**
点击「New Project」→ 项目名：`dazi-app` → 选择空白模板

**Step 4: 连接 Firebase**
Settings → Firebase → Connect Firebase
- 选择 `dazi-dev` 项目
- 按提示下载 `google-services.json`（Android）和 `GoogleService-Info.plist`（iOS）
- 上传到 FlutterFlow

**Step 5: 验证连接**
FlutterFlow 显示「Firebase Connected ✓」

---

### Task 3：申请第三方 API

**Step 1: Google Maps API**
- 前往 https://console.cloud.google.com
- APIs & Services → Enable APIs → 开启「Maps SDK for Android」「Maps SDK for iOS」「Places API」
- Create Credentials → API Key → 复制保存

**Step 2: Algolia 搜索**
- 前往 https://www.algolia.com → 注册免费账号
- 创建 Application：`dazi-search`
- 记录：`Application ID` 和 `Admin API Key` 和 `Search-Only API Key`

**Step 3: Claude API（Anthropic）**
- 前往 https://console.anthropic.com → 注册账号
- Create API Key → 复制保存
- 充值最低额度（$5）

**Step 4: 阿里云实人认证**
- 前往 https://www.aliyun.com → 注册企业账号
- 搜索「实人认证」→ 开通服务
- 获取 AccessKey ID 和 AccessKey Secret

**Step 5: Firebase Remote Config 存储所有 Key**
Firebase Console → Remote Config → 添加参数（密钥不能写在前端代码里）

---

## 阶段二：数据模型配置（Day 1-2）

### Task 4：在 Firestore 创建集合结构

在 FlutterFlow → Firestore → 依次创建以下集合和字段：

**Step 1: users 集合**
```
name: String
avatar: String (URL)
bio: String
gender: String (male/female/other)
birthYear: Integer
phone: String
tags: Array<String>
rating: Double (默认 5.0)
reviewCount: Integer (默认 0)
ghostCount: Integer (默认 0)
isRestricted: Boolean (默认 false)
verificationLevel: Integer (默认 1)
sesameAuthorized: Boolean (默认 false)
totalMeetups: Integer (默认 0)
badges: Array<String>
city: String
blockedUsers: Array<String>
createdAt: Timestamp
lastActive: Timestamp
```

**Step 2: posts 集合**
```
userId: String
category: String
title: String
description: String
images: Array<String>
time: Timestamp
location: Map {name, lat, lng, city}
totalSlots: Integer
minSlots: Integer (默认 2)
genderQuota: Map {male, female} (可为 null)
acceptedGender: Map {male:0, female:0}
costType: String (aa/host/self/tbd)
depositAmount: Integer (默认 0)
isInstant: Boolean (默认 false)
isSocialAnxietyFriendly: Boolean (默认 false)
waitlist: Array<String>
status: String (open/full/done/cancelled)
createdAt: Timestamp
expiresAt: Timestamp
shareUrl: String
```

**Step 3: applications 集合**
```
postId: String
applicantId: String
status: String (pending/accepted/rejected/waitlisted)
createdAt: Timestamp
expiresAt: Timestamp (createdAt + 24h)
```

**Step 4: matches 集合**
```
postId: String
chatId: String
participants: Array<String>
checkedIn: Array<String>
depositStatus: String (frozen/released/deducted)
status: String (confirmed/completed/ghosted)
meetTime: Timestamp
```

**Step 5: deposits 集合**
```
userId: String
matchId: String
amount: Integer
status: String (frozen/released/deducted)
paymentId: String
payChannel: String (wechat/alipay)
createdAt: Timestamp
settledAt: Timestamp
```

**Step 6: reviews / reports 集合**
```
reviews: matchId, fromUser, toUser, rating(Int), comment(String), tags(Array), createdAt
reports: fromUser, targetUser, reason(String), status(String), createdAt
```

**Step 7: 验证**
Firestore Console 显示所有集合已创建，字段类型正确

---

### Task 5：配置 Firebase Security Rules

Firebase Console → Firestore → Rules → 替换为以下规则：

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // users：本人可读写，其他人只读基础信息
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // posts：登录用户可读，发布者可修改
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }

    // applications：申请者和发布者可读
    match /applications/{appId} {
      allow read: if request.auth != null &&
        (request.auth.uid == resource.data.applicantId ||
         request.auth.uid == get(/databases/$(database)/documents/posts/$(resource.data.postId)).data.userId);
      allow create: if request.auth != null;
    }

    // deposits：仅本人可读，Functions 写入
    match /deposits/{depId} {
      allow read: if request.auth.uid == resource.data.userId;
      allow write: if false; // 只允许 Functions 写
    }

    // reports：任何登录用户可创建
    match /reports/{repId} {
      allow create: if request.auth != null;
      allow read: if false; // 只允许管理员读
    }
  }
}
```

**Step: 发布规则**
点击「Publish」，在 Firestore Simulator 测试规则是否生效

---

## 阶段三：核心页面构建（Week 1-3）

### Task 6：登录注册页

**Step 1: 创建登录页**
FlutterFlow → Pages → Add Page → 命名「LoginPage」
- 添加 Logo 图片组件
- 添加三个登录按钮：手机号 / Google / Apple
- 手机号按钮 → 跳转到手机号输入页

**Step 2: 手机号登录流程**
- 输入手机号页：TextField + 发送验证码按钮
  → Action: Firebase Auth → Phone Sign In → Send Code
- 输入验证码页：6位数字输入框
  → Action: Firebase Auth → Verify SMS Code
  → 成功：检查是否新用户 → 跳转 Onboarding 或 广场

**Step 3: Google 登录**
按钮 Action → Firebase Auth → Google Sign In
成功后同上逻辑

**Step 4: Apple 登录（iOS 必须）**
按钮 Action → Firebase Auth → Apple Sign In

**Step 5: 验证**
三种登录方式均能成功创建用户，Firebase Console → Authentication 显示新用户

---

### Task 7：注册引导（5步 Onboarding）

**Step 1: 创建 OnboardingPage**
顶部进度条（1/5 → 5/5）+ 右上角「跳过」按钮

**Step 2: Step 1 — 性别选择**
三个选项卡：男 / 女 / 不透露
选中后写入 `users/{uid}.gender`

**Step 3: Step 2 — 昵称 + 头像**
- TextField 输入昵称
- 头像上传：ImagePicker → 压缩到200KB → Firebase Storage → 写入 avatar URL
- AI头像优选：上传多张 → 调用 Firebase Function（内部调用 Claude Vision API）→ 返回推荐序号

**Step 4: Step 3 — 出生年份**
Dropdown 选择年份（1950-2008）
写入 `users/{uid}.birthYear`

**Step 5: Step 4 — 兴趣标签**
标签网格（多选），热门标签默认前置
右侧显示「已选 X 个」，至少选1个才能下一步
询问：「你是社恐吗？」→ 开启胆小鬼模式

**Step 6: Step 5 — 城市确认**
GPS 自动定位 → 显示「检测到：上海，确认吗？」
可手动切换城市

**Step 7: 完成**
写入所有数据 → 跳转广场首页 → 显示新手引导气泡（可跳过）

---

### Task 8：广场首页

**Step 1: 页面结构**
- 顶部：城市切换按钮 + 搜索栏
- 分类 Tab 横向滚动（6大类）
- 搭子卡片列表（ListView）
- 右下角：「即刻出发」浮动按钮

**Step 2: 搭子卡片组件**
创建可复用 Component「PostCard」：
```
图片轮播（images[]）
标题 + 时间 + 地点
人数进度条 + 男女比例动态显示
费用方式 + 发布者头像 + 评分 + 勋章
匹配度分数（本地计算：用户标签与帖子分类重叠度）
```

**Step 3: 数据查询**
Firestore Query → posts 集合
- 过滤：city == 当前城市，status == "open"，time > 当前时间
- 排序：个性化（有过历史的用户按标签匹配度排序，新用户按时间倒序）
- 分页：每次加载20条

**Step 4: 分类筛选**
点击一级分类 Tab → 过滤 posts.category 前缀
点击进入 → 显示二级分类下拉

**Step 5: 空状态**
无搭子时显示：「附近还没有搭子，成为第一个！」+ 发布按钮

**Step 6: 验证**
广场能正常加载帖子，筛选有效，空状态正确显示

---

### Task 9：发布搭子页

**Step 1: 表单页面结构**
滚动表单 + 底部固定「发布」按钮

**Step 2: 语音AI发布入口**
顶部「🎤 语音快速发布」按钮：
- 按住录音 → 设备原生 STT 转文字
- 调用 Firebase Function `parseVoicePost`
- Function 调用 Claude Haiku API，提取结构化字段
- 自动填入表单，用户确认修改后发布

**Step 3: 表单字段**
- 分类选择器（两级，ChipGroup 组件）
- 标题 TextField + 「AI帮我写」按钮（调用 Claude 补全描述）
- 图片上传（最多6张，客户端压缩至500KB）
- 时间选择器（DateTimePicker，只能选未来时间）
- 地点选择（Google Maps 地图 pin）
- 人数上限（Stepper 组件，2-50）
- 男女比例（可选，Slider 分别设置）
- 费用方式（4选1 按钮组）
- 押金金额（Slider，0-100，显示推荐金额参考）
- 社恐友好 Toggle

**Step 4: 发布前校验**
```
genderQuota.male + genderQuota.female ≤ totalSlots → 否则提示错误
未满18岁用户 → depositAmount 强制为0
title 不能为空
time 必须是未来时间
```

**Step 5: 发布成功**
写入 Firestore → 生成 shareUrl（Firebase Dynamic Link）
弹出分享面板：微信/朋友圈/小红书/微博/复制链接

**Step 6: 验证**
发布帖子出现在广场，字段正确，分享链接可打开

---

### Task 10：搭子详情页

**Step 1: 页面结构**
- 顶部图片轮播
- 基本信息（时间/地点/人数/费用/押金）
- 实时报名比例进度条（男/女分开显示）
- 发布者信息卡片（头像+勋章+评分+爽约次数）
- 活动描述
- 讨论区（评论列表 + 输入框）
- 底部：申请按钮 / 候补按钮（满员时）

**Step 2: 申请逻辑**
点击申请 → 检查：
1. 用户 verificationLevel >= 2（否则引导完成活体认证）
2. 年龄 >= 18（押金功能）
3. genderQuota 是否还有该性别名额
→ 创建 application 文档
→ FCM 通知发布者

**Step 3: 24h 过期**
Firebase Function `onApplicationCreate` → 设置定时任务
24h 后状态还是 pending → 自动改为 expired → FCM 通知申请者

**Step 4: 验证**
申请成功，发布者收到通知，满额时显示候补按钮

---

### Task 11：消息中心

**Step 1: 通知 Tab**
列表显示所有系统通知（申请/确认/签到提醒等）
从 Firebase Realtime Database `notifications/{uid}` 读取

**Step 2: 聊天列表**
显示所有进行中的聊天（从 matches 集合查询）

**Step 3: 聊天页面**
连接 Firebase Realtime Database `chats/{chatId}/messages`：
- 实时监听新消息
- 支持发送：文字 / 语音（按住录制）/ 图片 / 视频 / 位置
- 顶部显示搭子信息（时间/地点倒计时）
- 见面当天显示「紧急求助」按钮

**Step 4: 群聊 vs 私聊**
- 确认前：发布者与申请者私聊（2人）
- 确认后：所有参与者群聊（N人）

**Step 5: 验证**
发送各种类型消息均成功，实时接收无延迟

---

### Task 12：个人主页

**Step 1: 主页内容**
- 头像 + 昵称 + 勋章 + 城市
- 评分 + 评价数 + 爽约次数（公开）
- 芝麻信用授权标识（已授权显示）
- 兴趣标签列表
- 往期搭子记录（已完成的帖子）

**Step 2: 设置页**
- 编辑资料
- 胆小鬼模式开关
- 紧急联系人设置（最多3位，从手机联系人选取）
- 通知设置（各类通知开/关）
- 隐私设置
- 用户协议 / 隐私政策
- 注销账号（删除所有数据）
- 帮助与反馈（跳转微信客服）

**Step 3: 验证**
主页信息完整，设置保存有效

---

## 阶段四：防鸽子 + 押金系统（Week 3-4）

### Task 13：签到功能

**Step 1: 签到页面触发**
Firebase Function `onMeetTime`：
- 每分钟检查 matches 集合
- meetTime 到达 → status 改为 active
- FCM 通知所有参与者

**Step 2: 签到按钮**
见面当天活跃时 → App 顶部显示横幅「签到开始了！」
点击横幅 → 进入签到页

**Step 3: 二维码签到**
- 每个参与者生成唯一签到二维码（Firebase Dynamic Link + matchId + userId）
- 扫对方二维码 → 验证 matchId 和双方都在 participants[] 里
- 验证通过 → 写入 matches.checkedIn[]

**Step 4: GPS 签到备用方案**
获取当前位置 → 与 posts.location 对比
距离 < 200m → 验证通过

**Step 5: 超时处理**
Firebase Function `onCheckInTimeout`：
- 签到窗口关闭（meetTime + 60分钟）
- 未在 checkedIn[] 的参与者 → ghostCount +1
- 触发押金扣除逻辑
- 检查 isRestricted 条件

**Step 6: 验证**
完整走完签到流程，爽约方 ghostCount 正确+1，押金正确处理

---

### Task 14：微信/支付宝押金集成

> **注意：** 此任务需要已有营业执照 + 微信支付商户号 + 支付宝商家账号

**Step 1: Firebase Function 配置支付密钥**
```
firebase functions:config:set \
  wechat.appid="xxx" \
  wechat.secret="xxx" \
  wechat.mchid="xxx" \
  wechat.key="xxx" \
  alipay.appid="xxx" \
  alipay.privatekey="xxx"
```

**Step 2: 押金冻结 Function**
`freezeDeposit(matchId, userId, amount, channel)`
- 调用微信支付「预授权」API 或 支付宝「资金授权」API
- 记录到 deposits 集合，status: "frozen"

**Step 3: 押金释放 Function**
`releaseDeposit(depositId)`
- 双方签到成功后调用
- 调用支付 API 解冻资金
- 更新 deposits.status: "released"

**Step 4: 押金扣除 Function**
`deductDeposit(depositId)`
- 爽约超时后调用
- 调用支付 API 扣款
- 90% 分配给其他出席者（发起退款），10% 平台保留
- 更新 deposits.status: "deducted"

**Step 5: 验证**
测试模式下走完押金冻结→释放/扣除全流程，资金流向正确

---

### Task 15：评价系统

**Step 1: 评价触发**
签到完成后 → FCM 通知「去评价你的搭子」
评价窗口：签到后72小时内有效（非强制弹窗）

**Step 2: 评价页面**
- 1-5星评分
- 标签多选：守时 / 有趣 / 靠谱 / 下次还想约
- 文字评价（可选）
- 提交后更新对方 users.rating（加权平均）

**Step 3: 搭子回忆卡**
评价提交后 → Firebase Function 调用 Claude API 生成回忆卡文案
卡片内容：活动信息 + AI趣味总结 + App水印
提前生成，存入 Storage，用户点分享时直接调用

**Step 4: 验证**
评价成功，对方评分正确更新，回忆卡生成并可分享

---

## 阶段五：AI 功能集成（Week 4-5）

### Task 16：Claude API Firebase Function 封装

所有 Claude 调用都通过 Firebase Function 中转（保护 API Key）：

**`parseVoicePost(text)`** — 语音发布解析
```javascript
const prompt = `从以下语音转文字内容中提取搭子活动信息，返回JSON：
{category, title, time, location, totalSlots, costType, description}
内容：${text}`
// 调用 Claude Haiku API，返回解析结果
```

**`generateDescription(title, category)`** — AI描述助手
```javascript
const prompt = `为一个搭子活动写一段吸引人的简短描述（50字以内）
活动类型：${category}，标题：${title}`
```

**`generateIcebreakers(user1Tags, user2Tags, activity)`** — 破冰话题
```javascript
const prompt = `为即将见面的两个人生成3个破冰话题
用户A兴趣：${user1Tags}，用户B兴趣：${user2Tags}，活动：${activity}`
```

**`generateMonthlyReport(userId, monthData)`** — 月报
```javascript
const prompt = `根据用户本月搭子数据生成温暖有趣的月报文案
数据：${JSON.stringify(monthData)}`
```

**`generateRecapCard(matchData)`** — 回忆卡
```javascript
const prompt = `为完成的搭子活动生成一句温暖的总结（20字以内）
活动：${matchData.category}，参与人数：${matchData.count}`
```

---

### Task 17：Algolia 搜索集成

**Step 1: 配置 Algolia 索引**
在 Algolia Dashboard → Indices → Create Index：`posts`
配置可搜索字段：title, description, location.name, category

**Step 2: Firebase Extension 自动同步**
Firebase Extensions → 安装「Search with Algolia」
配置：Collection = posts，Fields = title/description/location/category

**Step 3: FlutterFlow 搜索页面**
- 搜索栏输入 → 调用 Algolia Search API（Search-Only Key，前端安全）
- 结果显示同广场卡片组件
- 筛选器：城市/时间/费用/社恐友好

**Step 4: 验证**
输入中文关键词能正确返回相关搭子

---

## 阶段六：社交飞轮功能（Week 5-6）

### Task 18：即刻出发

**Step 1: 发布即刻搭子**
点击广场右下角「⚡ 即刻出发」按钮
简化表单：分类 + 地点 + 人数（isInstant: true，expiresAt: now+30min）

**Step 2: 附近用户推送**
发布后 Firebase Function 查询同城市在线用户（lastActive < 30分钟）→ FCM 推送

**Step 3: 成团逻辑**
15分钟内 acceptedCount >= minSlots → 自动成团，通知所有人
否则 → 自动取消，全额退款（若有押金），无爽约记录

---

### Task 19：固定搭子群

**Step 1: 触发**
两个用户见面次数 >= 2 → 系统提示「要不要建个固定搭子群？」

**Step 2: 固定群创建**
同意 → 创建 Realtime DB 群聊
群内「下次约」按钮 → 快速发布新搭子（自动邀请群成员）

---

### Task 20：社交成长月报

**Step 1: 定时触发**
Firebase Function `generateMonthlyReport`
每月1日凌晨触发（Cloud Scheduler）

**Step 2: 数据统计**
查询用户上月：matches 完成数、新认识人数、探索地点数、最佳搭子

**Step 3: AI 生成文案**
调用 Claude API 生成个性化月报文案

**Step 4: 推送 + 分享**
FCM 通知「你的月报来了」→ 进入月报页 → 可分享到朋友圈（带水印）

---

## 阶段七：测试与上架（Week 6-7）

### Task 21：完整功能验证清单

```
□ 手机号/Google/Apple 三种登录均正常
□ 5步 Onboarding 完整流程
□ 发布搭子（表单/语音/AI描述）
□ 男女配额校验（male+female ≤ totalSlots）
□ 未成年押金拦截（birthYear → 年龄 < 18）
□ 搭子分享（各渠道）+ H5落地页 + DeepLink
□ 申请 → 确认 → 聊天开启
□ 申请24h过期
□ 押金冻结 → 签到成功释放
□ 押金冻结 → 爽约扣除 → 分配
□ ghostCount 正确累计，3次后 isRestricted
□ 候补系统（满员 → 加候补 → 有人退出 → 通知）
□ 评价 + 标签 + 回忆卡生成
□ 搜索中文关键词
□ 月报生成
□ 紧急求助按钮
□ 空状态（无搭子城市）
□ 新手引导气泡
```

### Task 22：提交 App Store

**Step 1: 在 FlutterFlow 导出 iOS 包**
Settings → App Settings → iOS → Build IPA

**Step 2: 上传到 TestFlight**
用 Xcode 或 Transporter 上传 IPA
邀请10-20个内测用户

**Step 3: 收集反馈，修复关键问题**
内测至少1周

**Step 4: 提交正式审核**
App Store Connect → 填写 App 信息 → 上传截图 → 提交审核
预计审核时间：1-3天

**必须准备：**
- App 隐私政策 URL（已上线的网页）
- 年龄分级（17+，因含押金功能）
- 紧急求助功能截图（审核员会查）

### Task 23：提交 Google Play

**Step 1: 在 FlutterFlow 导出 Android AAB**
Settings → App Settings → Android → Build AAB

**Step 2: Google Play Console 上传**
创建应用 → 上传 AAB → 填写商店信息 → 提交审核

**Step 3: 验证**
两个平台均显示「已发布」

---

## 阶段八：冷启动运营（上线后持续）

### Task 24：种子用户获取

**Week 1-2：**
- 手动邀请20-30位种子用户（朋友/社群）
- 自己发布前10条真实搭子，制造内容
- 只聚焦1个城市（如上海）

**Week 3-4：**
- 联系本地年轻人聚集地合作：livehouse/健身房/自习室
- 邀请好友注册得「押金减免券」
- 用户发布搭子后一键分享朋友圈

**Month 2+：**
- 搭子回忆卡病毒传播
- 月报分享
- 小红书/Soul发布搭子相关内容引流
- 扩展到第2个城市

---

## 关键里程碑

| 里程碑 | 目标时间 | 成功标准 |
|--------|---------|---------|
| 环境搭建完成 | Day 2 | Firebase + FlutterFlow 连通 |
| MVP 核心页面完成 | Week 3 | 能走完发布→申请→聊天流程 |
| 防鸽子系统完成 | Week 4 | 签到+押金+爽约全流程正常 |
| AI 功能完成 | Week 5 | 语音发布+破冰助手+月报正常 |
| TestFlight 内测 | Week 6 | 20人内测无崩溃 |
| 正式上架 | Week 7 | App Store + Google Play 审核通过 |
| 100个真实用户 | Month 2 | 自然增长，不靠买量 |
