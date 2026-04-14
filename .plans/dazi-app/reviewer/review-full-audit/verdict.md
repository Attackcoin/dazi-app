# T0b 审查判决

**审查员**: reviewer | **日期**: 2026-04-13 | **基线**: master@b415e19

---

## 总体判决: [WARN]

- **CRITICAL**: 0(原 2 条已闭环,独立复核确认)
- **HIGH 新发现**: 7 条(researcher T0a 漏标的业务逻辑并发/鉴权问题)
- **HIGH 沿用**: 2 条(测试覆盖 + i18n)
- **MEDIUM**: 9 条
- **LOW**: 8 条

RD-4 / RD-5 WEAK → 按 CLAUDE.md 规则**不能给 [OK]**,判 [WARN]。

---

## 维度评分表

| # | 维度 | 评分 | 关键证据 |
|---|------|------|---------|
| RD-1 UI 精美度 | **ADEQUATE**(近 STRONG) | Glass Morph 100% 覆盖,withOpacity=0 清零,profile_screen 820→327 |
| RD-2 产品边界 | **ADEQUATE** | AsyncValue.when + 骨架屏全覆盖;扣 6 处 retry 缺失 + GPS 签到绕过(M-1) |
| RD-3 Firebase 成本 | **ADEQUATE** | 索引 15 条 + limit + atomic increment;扣 openCheckinWindow 无索引(M-2) + v1/v2 混用 + 无缩略图 |
| RD-4 测试覆盖 | **WEAK** | 9 widget test / 核心 6 repo + 8 .js + rules 全部 0 单测 |
| RD-5 a11y/i18n | **WEAK** | intl 0 基建,Semantics 16 处 <20% 覆盖 |

---

## Top 15 优先修复(按严重度 × 成本排序)

| # | 条目 | 严重度 | 修复成本 | 负责人 | 备注 |
|---|------|--------|----------|--------|------|
| 1 | H-6 generateIcebreakers/RecapCard 未校验参与者 | HIGH | 5 分钟 | backend-dev | 加 4 行 if 即可,隐私泄漏立即补 |
| 2 | H-2 submitReview toUserId 未校验 | HIGH | 5 分钟 | backend-dev | 加 1 行 includes 校验 |
| 3 | H-1 applyToPost 并发重复申请 | HIGH | 30 分钟 | backend-dev | 改用确定性 doc id |
| 4 | H-3 submitReview 非事务 | HIGH | 15 分钟 | backend-dev | 用 batch/transaction |
| 5 | H-4 submitCheckin 并发双触发 totalMeetups | HIGH | 30 分钟 | backend-dev | 合并入 runTransaction + CAS |
| 6 | H-5 ghostCount read-modify-write | HIGH | 10 分钟 | backend-dev | FieldValue.increment |
| 7 | H-7 deposits 幂等性缺失 | HIGH | 30 分钟 | backend-dev | 确定性 id + 状态 CAS |
| 8 | M-1 GPS 签到可绕过 | MED | 20 分钟 | backend-dev | 强制坐标上报 |
| 9 | M-3 applications rules applicantId 白名单 | MED | 5 分钟 | backend-dev | rules 一行 |
| 10 | M-9 acceptApplication 满员后清理 pending | MED | 30 分钟 | backend-dev | |
| 11 | M-5 generateMonthlyReports 串行 + 月份 bug | MED | 30 分钟 | backend-dev | Promise.all + fix label |
| 12 | H-8 Functions 关键单测(applications/antiGhosting/deposits) | HIGH | 4 小时 | backend-dev | 覆盖 H-1~H-7 回归 |
| 13 | H-8 client Repository 单测(6 个) | HIGH | 4 小时 | frontend-dev | auth/application/match/chat/review/checkin |
| 14 | M-6 6 处 error retry 补齐 | MED | 1 小时 | frontend-dev | |
| 15 | M-2 openCheckinWindow 索引 | MED | 5 分钟 | backend-dev | firestore.indexes.json +1 |

---

## T1 / T2 分工建议

**T1 (backend-dev, 必须先行)**: H-1~H-7 + M-1,M-3,M-9,M-5(共 11 项后端业务逻辑/安全修复,约 4-5 小时)。**每修一项加对应单测**,一并完成 H-8 的 functions 层测试(Top#12)。

**T1 并行 (frontend-dev)**: H-8 client 层 6 个 Repository 单测(Top#13,约 4 小时) + M-6 error retry 统一 widget(Top#14)。

**T2 (backend-dev + custodian)**: M-2 索引补全,M-8 v1→v2 迁移评估,firestore.rules 回归测试脚手架(AUTOMATE-1 转 custodian)。

**T2 (frontend-dev)**: M-4 chat N+1,M-7 距离筛选落地或移除,LOW backlog 清单。

**不在本阶段做**:RD-5 i18n/a11y 全量改造(backlog,除非出海);LOW 级全部。
