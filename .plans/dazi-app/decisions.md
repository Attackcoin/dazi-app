# dazi-app - 架构决策记录

---

## AD-1: 群聊架构 (2026-04-12)
- **决策**: 每个 post 对应一个群聊，postId = chatId
- **理由**: 简化数据模型，一个局一个聊天室

## AD-2: 状态管理 (2026-04-09)
- **决策**: Riverpod Provider + StreamProvider only, 禁止 Notifier/StateNotifier
- **理由**: 用户偏好，保持简单

## AD-3: 聊天存储 (2026-04-09)
- **决策**: Firebase Realtime Database 存消息，Firestore 存 lastMessage 摘要
- **理由**: RTDB 适合高频实时消息，Firestore 适合结构化查询

## AD-4: 全球化双轨策略 (2026-04-17)
- **决策**: 国内 + 海外双轨运营，不放弃任何一方
- **理由**: 搭子文化起源中国（72.6% 年轻人已有搭子），但"activity buddy"是全球需求（WHO 孤独危机报告、Strava 跑团 +59%、Timeleft 52 国）
- **执行**: i18n 中英双语 → 海外首站英语市场 → 后续扩展
- **国内特殊处理**: 支付(微信/支付宝)、推送(华为/小米)、合规(隐私政策/账号注销)、审核(腾讯云)

## AD-5: 产品定位 — 活动驱动非匹配驱动 (2026-04-17)
- **决策**: 不做 swipe-for-friends，不做横向泛交友，专注"活动闭环"
- **理由**: Bumble BFF (swipe 模式) 失败、Meetup (老龄化)、IRL (倒闭) 证明纯匹配不可持续。Timeleft (€18M ARR) + Clyx ($14M A轮) 证明"线下仪式感 + 重复出现"才是护城河
- **核心差异**: 押金系统(到场保障) + 防鸽子(签到+爽约记录) + AI 辅助(破冰/回忆卡) + 身份验证

## AD-6: 地理搜索保持 Algolia (2026-04-17)
- **决策**: 不引入 Mapbox，地理搜索继续用 Algolia GeoSearch
- **理由**: 已有 Algolia 基础设施 + _geoloc 字段同步，减少 vendor 数量。Google Places Autocomplete 仅用于发帖选点

## AD-7: 身份验证多级 (2026-04-17)
- **决策**: verificationLevel 三级：1=手机号, 2=证件(Stripe Identity), 3=人脸活体
- **理由**: Stripe Identity $1.50/次覆盖 120 国，NomadHer/Peanut 数据证明"验证即获客"（女性注册转化翻倍）
- **关键设计**: 验证绑定到"显示资料"和"开启 1:1 聊天"，女性可筛选"仅已验证用户"
