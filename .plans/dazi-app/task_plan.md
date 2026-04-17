# dazi-app - 主计划

> 状态: PHASE-5 COMPLETE — 全球化 + 产品深化
> 创建: 2026-04-09
> 更新: 2026-04-17 (Phase 5 全部完成 — 21 个任务)
> 团队: dazi-app (backend-dev, frontend-dev, researcher, e2e-tester, reviewer, custodian)
> 决策记录: .plans/dazi-app/decisions.md
> 调研报告: .plans/dazi-app/researcher/research-social-trends/findings.md

---

## 1. 项目概述

Flutter + Firebase 社交搭子 App（找人一起吃饭/运动/演唱会/游戏等）。
**面向全球用户，双轨运营（国内 + 海外）**。
核心玩法：发布活动 → 申请加入 → 匹配组局 → 群聊 → 签到 → 互评。
技术栈：Flutter 客户端 / Firebase Functions (Node.js) / Firestore / RTDB / Algolia (搜索+地理)。

---

## 2. 文档索引

| 文档 | 位置 | 内容 |
|------|------|------|
| 架构 | docs/architecture.md | 系统组件、数据流、关键设计决策 |
| API 契约 | docs/api-contracts.md | 前后端接口定义 |
| 不变量 | docs/invariants.md | 不可违反的系统边界 |
| 竞品调研 | researcher/research-social-trends/ | 全球社交 APP 趋势 + 竞品分析 |

---

## 3. 已完成阶段

- Phase 0: 需求对齐 + 代码盘点 ✓
- Phase 1: 安全/质量审查 + 修复 ✓
- Phase 2: 垂直切片优化 ✓ (T2a-T2f)
- Phase 3: E2E 测试 ✓ (J0-J7)
- Phase 4: 合规巡检 + Glass Morph UI 升级 ✓
- Phase 4.5: 架构审查修复 ✓ (2026-04-16/17, 3×P0 + 6×P1)
- Phase 5: 全球化 + 产品深化 ✓ (2026-04-17, T5-01 ~ T5-21 全部完成)

---

## 4. Phase 5 — 全球化 + 产品深化 ✅

### 战略方向（基于调研）

核心定位：**"活动为本、弱关系、重复出现、安全优先"的垂直社交产品**
- 不做 swipe-for-friends（Bumble BFF 失败路线）
- 不做横向泛交友（Meetup 老龄化路线）
- 做深"发帖→匹配→到场→互评"闭环，叠加身份验证 + 重复活动组

双轨策略：
- **海外轨**：英语优先，首站纽约或伦敦，演唱会/跑团为 wedge
- **国内轨**：中文，一线城市，搭子文化天然基础

---

### 5.1 立即行动 — P0（1-2 周）

| # | 任务 | 负责人 | 依赖 | 难度 |
|---|------|--------|------|------|
| T5-01 | **身份验证系统 + 已验证徽章** | backend-dev + frontend-dev | Stripe Identity API | 中 |
| | — 接入 Stripe Identity（海外）或腾讯云人脸核身（国内） | | | |
| | — `verificationLevel` 升级逻辑：1=手机号, 2=证件, 3=人脸 | | | |
| | — ProfileScreen / PostCard 显示 ✓ 已验证徽章 | | | |
| | — 验收：用户完成验证后 badge 可见，女性可筛选"仅已验证用户" | | | |
| T5-02 | **PostCard 展示押金保障标签** | frontend-dev | 无 | 低 |
| | — `depositAmount > 0` 时在 PostCard 显示"💰 押金保障"PillTag | | | |
| | — PostDetailScreen 展示押金金额和说明 | | | |
| | — 验收：有押金的帖子视觉上明显区别 | | | |
| T5-03 | **活动后轻量反馈（"见到了吗？"）** | backend-dev + frontend-dev | 无 | 低 |
| | — match 完成后推送简单二选一："见到了 👍 / 没见到 👎" | | | |
| | — 写入 `matches/{id}.quickFeedback.{uid}` | | | |
| | — 用于后续匹配算法训练信号（Hinge "We Met?" 模式） | | | |
| | — 验收：签到完成后弹出反馈卡，回复率 > 详细评价 | | | |

### 5.2 短期 — P1（1-3 月）

| # | 任务 | 负责人 | 依赖 | 难度 |
|---|------|--------|------|------|
| T5-04 | **地理搜索增强（Algolia GeoSearch）** | frontend-dev + backend-dev | 无 | 中 |
| | — Algolia 已有 `_geoloc` 字段，启用 aroundLatLng 地理搜索 | | | |
| | — CreatePostScreen：接入 Google Places Autocomplete 选点 | | | |
| | — DiscoverScreen：按距离排序 + "附近活动"入口 | | | |
| | — 海外/国内都走 Algolia 统一地理索引 | | | |
| | — 验收：用户可按距离发现活动，发帖可搜索地点 | | | |
| T5-05 | **i18n 国际化基础** | frontend-dev | 无 | 中 |
| | — 接入 `flutter_localizations` + `intl` 生成 .arb 文件 | | | |
| | — 抽取所有硬编码中文为 l10n key | | | |
| | — 首批支持：中文简体 (zh) + 英文 (en) | | | |
| | — 系统语言自动切换 + 手动切换入口 | | | |
| | — 验收：切英文后所有页面无中文硬编码 | | | |
| T5-06 | **重复活动组 / Programs**（Clyx 模式） | backend-dev + frontend-dev | 无 | 高 |
| | — Post 模型加 `seriesId` + `recurrence` (weekly/biweekly) + `seriesWeek` | | | |
| | — 创建帖子时可选"连续 N 周"，自动生成系列帖子 | | | |
| | — 系列帖子共享参与者，连续 4 周同组人见面 | | | |
| | — 理论依据：Marisa Franco "重复的、非计划的、群组接触 = 友谊" | | | |
| | — 验收：用户可创建/加入系列活动，每周自动开新一期 | | | |
| T5-07 | **演唱会/展览搭子垂直场景** | frontend-dev | 无 | 低 |
| | — Post 分类加 `演出 > 演唱会/音乐节/展览/体育赛事` | | | |
| | — 帖子可关联外部事件（eventName + eventDate + venue） | | | |
| | — 首页 banner / 热门事件聚合入口 | | | |
| | — 冷启动 wedge：绑定 2026 下半年热门巡演 | | | |
| | — 验收：演唱会类帖子有专属 UI，事件聚合页可浏览 | | | |
| T5-08 | **深度链接 + 分享** | frontend-dev + backend-dev | Firebase Dynamic Links 或 uni_links | 中 |
| | — `shareUrl` 字段启用，生成可分享链接 | | | |
| | — Flutter share sheet 集成 | | | |
| | — 链接打开后直接跳转到帖子详情（已有 post.html Hosting） | | | |
| | — 未安装 APP 时跳转到应用商店或 Web 预览 | | | |
| | — 验收：分享到 WhatsApp/微信/iMessage 可点击打开 | | | |
| T5-09 | **女性 Only 活动模式** | backend-dev + frontend-dev | T5-01 验证系统 | 低 |
| | — Post 加 `womenOnly: bool` 字段 | | | |
| | — Rules 强制：womenOnly=true 的帖子只有 gender=female 且 verified 可申请 | | | |
| | — Discover 页"女性专区"筛选标签 | | | |
| | — 验收：女性 only 帖子对男性/未验证用户不可申请 | | | |

### 5.3 中期 — P2（3-6 月）

| # | 任务 | 负责人 | 依赖 | 难度 |
|---|------|--------|------|------|
| T5-10 | **Embedding 智能推荐** | backend-dev | Vertex AI / OpenAI API | 高 |
| | — Functions 发帖时调 Embedding API 生成向量存 `posts/{id}.embedding` | | | |
| | — 用户 bio + tags 也生成 embedding 存 `users/{id}.embedding` | | | |
| | — Firestore Vector Search `findNearest` 做个性化 feed 召回 | | | |
| | — 替代当前纯城市+分类过滤，实现"懂你的推荐" | | | |
| | — 成本：10 万帖子嵌入 ≈ $1（text-embedding-3-small） | | | |
| T5-11 | **按活动付费模式** | backend-dev + frontend-dev | Stripe 已有 | 中 |
| | — 帖子可设"参与费" $3-5（Breeze 模式：激励对齐） | | | |
| | — 与现有押金系统并行，活动费 = 平台收入 | | | |
| | — 发布者可设免费/付费，平台抽 15-20% | | | |
| T5-12 | **AI 安全伴侣** | backend-dev | T5-01 | 中 |
| | — 签到窗口超时且未签到 → 自动通知紧急联系人 | | | |
| | — 活动开始后"平安签到"一键确认 | | | |
| | — 借鉴 Flare/Noonlight 模式 | | | |
| T5-13 | **多地区 Firebase 部署** | backend-dev | 无 | 高 |
| | — 海外用户走 us-central1 或 europe-west1 Functions | | | |
| | — 国内用户走 asia-southeast1（现有） | | | |
| | — Firestore 多区域复制或按市场独立项目 | | | |
| | — 方案选型需 researcher 调研 | | | |
| T5-14 | **全球支付** | backend-dev | T5-11 | 高 |
| | — 海外：Stripe（已有基础设施） | | | |
| | — 国内：微信支付 / 支付宝 | | | |
| | — RevenueCat 统一订阅管理（如引入会员） | | | |
| T5-15 | **内容审核多语言** | backend-dev | T5-05 i18n | 中 |
| | — OpenAI Moderation API（免费）处理英文 | | | |
| | — 中文走现有方案或接腾讯云内容安全 | | | |
| | — 图片审核：Sightengine ($29/月 10k 次) | | | |

### 5.4 长期 — P3（6-12 月）

| # | 任务 | 描述 | 难度 |
|---|------|------|------|
| T5-16 | 兴趣圈子/社群 | 帖子体系之外建立持久社群（运动圈/吃货圈），解决搭子"用完即走"留存问题 | 高 |
| T5-17 | 行为信任分 | no-show 累计扣分 + 好评加分，低分限制发帖/加入 | 中 |
| T5-18 | B2B 活动场地合作 | 咖啡厅/健身房/餐厅合作引流，活动到场佣金 | 高 |
| T5-19 | 更多语言支持 | 西班牙语、日语、韩语、法语、德语 | 中 |
| T5-20 | 语音房功能 | Geneva 模式的轻量语音聊天室 | 高 |
| T5-21 | SEO 着陆页矩阵 | "find [activity] partner in [city]" × 50 城市 × 20 活动类型 | 低 |

---

## 5. 全球化架构决策（待定）

需要 researcher 调研后确认：

| 决策点 | 选项 A | 选项 B | 当前倾向 |
|--------|--------|--------|---------|
| 地理搜索 | **Algolia GeoSearch**（已有基础设施） | Google Maps Platform | Algolia |
| 海外 Functions 区域 | us-central1 + europe-west1 | 单一 us-central1 | 待定 |
| 国内外数据隔离 | 同一 Firebase 项目 | 独立项目 | 待定 |
| 支付 | Stripe 全球 + 微信/支付宝国内 | Stripe only | 双轨 |
| 推送 | FCM 全球 + 华为/小米国内 | FCM only | 双轨 |
| 应用商店 | Google Play + App Store + 国内安卓市场 | GP + AS only | 三轨 |

---

## 6. 里程碑（历史）

### 2026-04-17 Phase 5 全部完成

- **P0 (3)**: T5-01 身份验证+徽章, T5-02 押金保障标签, T5-03 活动后反馈
- **P1 (6)**: T5-04 GeoSearch, T5-05 i18n 基础, T5-06 重复活动组, T5-07 演出垂直场景, T5-08 深度链接分享, T5-09 女性 Only 模式
- **P2 (6)**: T5-10 Embedding 推荐, T5-11 按活动付费, T5-12 AI 安全伴侣, T5-13 多地区部署, T5-14 全球支付, T5-15 内容审核多语言
- **P3 (6)**: T5-16 兴趣圈子, T5-17 行为信任分, T5-18 B2B 场地合作, T5-19 更多语言(ja/ko/es/fr/de), T5-20 语音房, T5-21 SEO 着陆页矩阵(1000页)
- Flutter analyze: 0 error, 0 warning, 4 info（既有）
- Functions tests: 205 passing
- i18n: 7 种语言（zh/en/ja/ko/es/fr/de）
- SEO: 50 城市 × 20 活动类型 = 1000 着陆页 + sitemap.xml

### 2026-04-17 架构审查修复完成

- 3 个 P0 bug 修复（rules 白名单 / ChatRepository 写入目标 / GoRouter 重建）
- 6 个 P1 改进（Tab 状态保持 / RTDB 规则 / 图片缓存 / 游标分页 / 页面转场 / 未读 badge）
- `flutter analyze` 零错误
- 已部署：firestore.rules + database.rules.json + indexes + Cloud Functions（含新 onNewChatMessage 触发器）

### 2026-04-12 Glass Morph UI 全面升级完成

- 21 个页面统一 Glass Morph 深色优先双主题
- Phase 1-5 共 40 个子任务
- CI 46/46 通过

### 2026-04-11 T0-T4 全面审查优化完成

- E2E 覆盖 8 个 journey
- CI 全绿（Flutter 50/50 + Functions 31/31）
