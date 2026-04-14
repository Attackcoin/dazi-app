# T0b 审查汇报 — to team-lead

**审查员**: reviewer | **日期**: 2026-04-13 | **基线**: master@b415e19

## 判决: [WARN]

RD-1/2/3 ADEQUATE,**RD-4/5 WEAK** → 按规则不能 [OK]。

## 维度评分

| RD-1 UI | RD-2 边界 | RD-3 成本 | RD-4 测试 | RD-5 a11y/i18n |
|---|---|---|---|---|
| ADEQUATE | ADEQUATE | ADEQUATE | WEAK | WEAK |

## 新发现

- **CRITICAL**: 0(原 2 条已闭环独立确认)
- **HIGH 新**: 7 条(T0a 漏标的后端业务逻辑/鉴权 race)
- HIGH 沿用 2 + MED 9 + LOW 8

## Top 5 必修(全部后端,成本合计 <2h)

1. **H-6** generateIcebreakers/RecapCard 未校验 `auth.uid ∈ match.participants` — 任意用户可生成任意 match 内容,隐私泄漏(`ai.js:123,187`)
2. **H-2** submitReview 未校验 `toUserId ∈ participants` — 可污染他人 rating(`applications.js:265`)
3. **H-1** applyToPost existingApp 非事务读 — 并发可重复申请(`applications.js:35`)
4. **H-4** submitCheckin 非事务 + allCheckedIn 并发双触发 → totalMeetups 被 increment 2 次(`antiGhosting.js:110`)
5. **H-7** freezeDeposit/depositPaymentCallback 缺幂等 + 状态 CAS — 重复回调会覆盖 refunded(`deposits.js:93,152`)

## T1/T2 分工

**T1**: backend-dev 修 H-1~H-7 + M-1/M-3/M-9/M-5 并补对应 Functions 单测;frontend-dev 并行补 6 个 Repository 单测 + M-6 error retry 组件。T1 完成后 RD-4 可升 ADEQUATE → 允许 [OK]。**T2**: 索引补全 + v1→v2 迁移 + custodian rules-unit-testing 脚手架;i18n/a11y backlog。

详细: `.plans/dazi-app/reviewer/review-full-audit/findings.md` + `verdict.md`
