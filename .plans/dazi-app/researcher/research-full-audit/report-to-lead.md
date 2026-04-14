# T0a 全面盘点 — 汇报给 team-lead

执行: researcher | 日期: 2026-04-13 | 范围: client 73 dart + functions 8 js + rules/indexes

## 核心结论 (6 条)

1. [良] 原 2 CRIT + 10 HIGH 已大量闭环(rules 字段白名单 / indexes +9 / HMAC 签名 / withdrawApp 走 Function / submitReview 原子 increment / repo .limit)。CRITICAL 残留 = 0。
2. [中-HIGH] SD-5 违反:`withOpacity(` 残留 16 处 / 10 文件(profile_screen 独占 8),必须替换成 `.withValues(alpha:)`。
3. [中-HIGH] 黄金原则 800 行超标:`profile_screen.dart = 820`(上次审计 770),必须拆分。
4. [中] RD-5 i18n 评级 WEAK:全项目 0 处 intl/AppLocalizations,全硬编码中文;Semantics 仅 16 处/9 文件,滑卡/聊天/评价/扫码等关键交互零语义。
5. [中] RD-4 测试 WEAK:client test 9 个(新增 dazi_colors/glass_button/glass_card),但 auth/application/match/chat/review/checkin 等核心 Repository 和所有 functions/*.js 仍 0 单测。
6. [中] 产品边界 stub/TODO 未消化:押金 SDK、STT、地图选点、回忆卡分享、post_card 缺 publisher/participant avatar、generateIcebreakers 无前端入口。需与用户对齐 MVP 范围。

## RD-1~5 初判

| 维度 | 评级 |
|---|---|
| RD-1 UI 精美度 | ADEQUATE(接近 STRONG,Glass Morph 36/36 覆盖,扣 withOpacity + 6 处 error 无 retry) |
| RD-2 产品边界 | ADEQUATE(骨架/空态/AsyncValue.when 全覆盖,扣 retry/N+1/距离筛选 UI 误导) |
| RD-3 Firebase 成本 | ADEQUATE(索引+limit+原子 increment 已做,扣 v1/v2 混用+无缩略图+openCheckinWindow 1min) |
| RD-4 测试覆盖 | WEAK |
| RD-5 a11y/i18n | WEAK |

## Top 10 优化机会

1. [HIGH] profile_screen 820→拆分(黄金原则违反)
2. [HIGH] 16 处 withOpacity → withValues(alpha:) (SD-5)
3. [HIGH] 6 个核心 Repository 单测补齐
4. [HIGH] Functions 关键事务单测(acceptApplication/submitReview/expireApplications)
5. [MED] 6 处 error 分支加 retry(post_detail/review/messages/chat/checkin/recap_card)
6. [MED] 发现页距离筛选落地或移除(discover_screen.dart:112,148)
7. [MED] chat_screen N+1 senderName 批量化
8. [MED] storage-resize-images Extension + 列表缩略图
9. [MED] openCheckinWindow 1min→5min + 窄索引
10. [MED] 引入 intl + arb 基建(文案先留中文)

Backlog: 回忆卡分享 / 破冰话题入口 / Profile 参加过 Tab / 候补晋升 Function / 帖子到期 Function / v1→v2 SDK 迁移 / monthlyReports 串行超时 / Semantics 全量补齐 / rules-unit-testing 回归(AUTOMATE-1)。

## 给 reviewer T0b 的重点建议

1. **优先** SD-5 深审(每处 withOpacity 是否应进 GlassTheme palette)
2. **优先** Glass Morph 21 页面交互一致性 checklist(圆角/间距/模糊/overlay pump 模板)
3. **优先** RD-2 边界:无网/慢网/键盘/权限拒绝/多设备登录/写冲突
4. **优先** 事务正确性:acceptApplication 80 行 / onCheckinTimeout 状态机
5. RD-4 已有测试 mock 耦合审查
6. RD-5 a11y 基线:列出所有零 Semantics 交互 + 图片 alt 缺失
7. 13 处 Firestore listener 的 Provider autoDispose/family 正确性
8. Functions 冷启动 + v1/v2 统一评估
9. 补 @firebase/rules-unit-testing 回归(AUTOMATE-1)
10. 死代码复检:deposits.freezeDeposit(KP-6 候选)/ category_config / 已 @Deprecated AppColors

## 产物

- 详细 findings: `.plans/dazi-app/researcher/research-full-audit/findings.md` (含 2026-04-13 增量复核段)
- 根索引: `.plans/dazi-app/researcher/findings.md` 已更新
