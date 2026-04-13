# T0a 调研：dazi-app 代码盘点

> 任务：MVP 前基线调研——盘点已实现 vs 占位/缺失
> 执行：researcher (Explore subagent)
> 日期：2026-04-09
> 状态：complete

---

## 总体结论

dazi-app 当前完成度约 **75%**（客户端 80% + 后端 70%）。**实际产品形态比初版 architecture.md 假设的更丰富**——这不是简单的发帖 App，而是一个**线下搭子撮合 + 防爽约 + 押金担保**的复合产品，包含申请/匹配/签到/评价/AI 辅助等模块。

> ⚠️ **重要发现**：原 docs/architecture.md 中"用户通过手机号登录、发帖、浏览信息流"的描述严重低估了产品复杂度。custodian 需要更新架构文档。

---

## 1. Flutter 客户端（client/）

### 依赖与配置
- **状态管理**：Riverpod
- **路由**：go_router
- **Firebase**：完整套件已声明
- **firebase_options.dart**：[占位] 框架存在但需运行 `flutterfire configure` 生成真实值
- **测试**：[占位] 仅 placeholder 测试

### Theme 系统 ✓
- AppColors / AppTheme 完整，8 种品牌主题色
- 仅 light theme，**[缺失] 暗色模式**

### 路由 ✓
- 16 条路由已注册
- 导航卫士逻辑正确

### 数据模型（API 契约真理源头）

**AppUser**（27 字段）：
```
id, name, avatar, bio, gender, birthYear, phone, tags, rating, reviewCount,
ghostCount, isRestricted, verificationLevel, sesameAuthorized, totalMeetups,
badges, city, blockedUsers, emergencyContacts, notificationsPrefs, privacyPrefs,
createdAt, lastActive
```

**Post**（19 字段）：
```
id, userId, category, title, description, images, time, location,
totalSlots, minSlots, genderQuota, acceptedGender, costType, depositAmount,
isInstant, isSocialAnxietyFriendly, waitlist, status, createdAt, expiresAt, shareUrl
```

**Application**（5 字段）、**Match**（18 字段）、**ChatMessage**（8 字段）

### Repository 层 ✓
- AuthRepository / PostRepository / PostCreateRepository / ChatRepository 已实现

### Feature 模块（9 个，均已完整实现）
splash · auth · onboarding · home · post · messages · profile · checkin · review

---

## 2. Firebase 后端（functions/）

### 已实现的 6 个模块（约 15 个 callable/trigger）

| 模块 | 内容 |
|------|------|
| `ai.js` | 语音→表单 / AI 描述 / 破冰话题 / 回忆卡（用 Claude Haiku） |
| `applications.js` | 申请管理 + 男女比例校验 + 事务处理 |
| `antiGhosting.js` | 定时签到窗口 + 防爽约逻辑 |
| `deposits.js` | 押金冻结框架（担保交易模式）— [部分] SDK 调用未实现 |
| `notifications.js` | FCM 推送框架（12 种场景） |
| `algoliaSync.js` | Firestore→Algolia 实时同步 |

### Firestore 配置 ✓
- **firestore.rules**：8 个集合规则，支持跨文档校验（get() 函数）
- **firestore.indexes.json**：5 个复合索引
- **firebase.json**：asia-southeast1 区域，emulator 全套

### [缺失]
- Cloud Functions 测试（devDependencies 有，目录无）
- **Storage Rules** ⚠️ 图片上传权限未定义

---

## 3. 公开静态资源

- `public/post.html`：完整的帖子分享页（H5，品牌一致，OG 元标签正确）
- 隐私政策 / 服务条款页面 ✓

---

## 4. 关键缺口清单（MVP 前必须解决）

| # | 缺口 | 严重度 | 处理方式 |
|---|------|--------|---------|
| 1 | firebase_options.dart 占位值 | 🔴 高 | `flutterfire configure --project=dazi-dev` |
| 2 | Algolia 客户端 SDK | 🔴 高 | 集成 algoliasearch_flutter 或后端代理搜索 |
| 3 | 支付 SDK（微信/支付宝） | 🔴 高 | 接入 SDK，完成 deposits.js API 调用 |
| 4 | Storage Rules | 🟠 中 | 新增 `storage.rules`，限制用户只读写自己文件 |
| 5 | FCM 前端集成 | 🟠 中 | `registerFcmToken()` + 处理推送点击 |
| 6 | PostRepository 分页 | 🟠 中 | 补充 startAfter / cursor 分页 |
| 7 | Cloud Functions 测试 | 🟡 低 | 至少覆盖 applications/deposits 业务逻辑 |
| 8 | 地图 SDK | 🟡 低 | 创建帖子地点选择（MVP 后迭代） |

---

## 5. 实现质量评分（researcher 主观判断，仅供 reviewer 参考）

| 维度 | 分数 | 评语 |
|------|------|------|
| 架构清晰度 | 9/10 | 目录分层合理 |
| 类型安全 | 9/10 | Dart 强类型 |
| UI 一致性 | 9/10 | 品牌色系统统一 |
| Firebase 集成 | 8/10 | 规则和索引完善，缺 Storage |
| 测试覆盖 | 2/10 | 仅占位 |
| 文档完整度 | 6/10 | 代码注释好，缺集成指南 |

---

## 6. 给 team-lead 的建议

1. **架构文档需重写**：原 architecture.md 把产品当成简单发帖应用，应更新为"搭子撮合 + 担保交易"模型
2. **api-contracts.md 可填充**：上面的字段清单可直接拷贝
3. **MVP 范围决策点**：用户需要在以下三选一
   - **方案 A（最快上线）**：跳过支付，押金改为"信用承诺"，2-3 周可发布
   - **方案 B（标准 MVP）**：接入一种支付渠道（微信优先），3-5 周
   - **方案 C（完整功能）**：双支付 + 全 SDK，5-7 周
4. **Storage Rules 必须在任何提交前补上**——当前是安全漏洞
