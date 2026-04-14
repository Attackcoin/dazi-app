# task-t1-tests-and-retry 任务计划

> 基线: master@b415e19 | 来源: `.plans/dazi-app/reviewer/review-full-audit/findings.md` H-8 / M-6
> 完整决策: `C:\Users\CRISP\.claude\plans\lazy-fluttering-chipmunk.md` PART B

## 目标

1. 6 个 core Repository 添加单测（match/application/auth/review/checkin/chat），覆盖正常 + 边界
2. 抽 `ErrorRetryView` 组件放 `client/lib/widgets/glass/`，替换 7 处硬编码 error 分支（不动 home_screen）
3. CI 全绿；请 reviewer 复审 M-6 标记为 ADDRESSED

## 验收标准

- 6 个 `test/data/repositories/*_test.dart` 新文件 + 1 个 widget test 全绿
- `python scripts/run_ci.py` PASS
- SD-5 合规（GlassTheme.colors / Spacing / Radii，禁 withOpacity/硬编码）
- `git status` 改动符合 PART C.2 frontend 清单

## 依赖

- plan: `C:\Users\CRISP\.claude\plans\lazy-fluttering-chipmunk.md`
- 侦察: `C:\Users\CRISP\.claude\plans\lazy-fluttering-chipmunk-agent-ae614e1feebf011b5.md`
- reviewer findings: `.plans/dazi-app/reviewer/review-full-audit/findings.md` (H-8, M-6)

## 范围边界（不做）

- 不改 Repository 公共 API
- 不动 home_screen retry
- 不处理 H-9（i18n/a11y）
- 不测 sendPhoneCode 的 verifyPhoneNumber 回调
