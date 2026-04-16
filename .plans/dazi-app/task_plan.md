# dazi-app - 主计划

> 状态: AUDIT-AND-OPTIMIZE (T0-T4 全部完成)
> 创建: 2026-04-09
> 更新: 2026-04-12 (Glass Morph UI 升级完成)
> 团队: dazi-app (backend-dev, frontend-dev, researcher, e2e-tester, reviewer, custodian)
> 决策记录: .plans/dazi-app/decisions.md

---

## 1. 项目概述

Flutter + Firebase 社交搭子 App（找人一起吃饭/运动/游戏等）。
核心玩法：Tinder 式滑卡加入局 → 群聊 → 活动结束互评。
技术栈：Flutter 客户端 / Firebase Functions (Node.js) / Firestore / Realtime Database (聊天) / Algolia (搜索)。

---

## 2. 文档索引

| 文档 | 位置 | 内容 |
|------|------|------|
| 架构 | docs/architecture.md | 系统组件、数据流、关键设计决策 |
| API 契约 | docs/api-contracts.md | 前后端接口定义 |
| 不变量 | docs/invariants.md | 不可违反的系统边界 |

---

## 3. 阶段概览

### 当前任务：全面审查与优化

用户要求以 TikTok/Uber 级别工程师标准，对整个 App 进行全面审查和优化。

### 阶段

- 阶段 0: 代码库盘点 — researcher 全面扫描现有代码，找出缺口和优化点
- 阶段 1: 审查 — reviewer 对现有代码做深度审查，按审查维度评分
- 阶段 2: 优化开发 — frontend-dev + backend-dev 按审查结论修复和优化
- 阶段 3: E2E 测试 — e2e-tester 验证关键流程
- 阶段 4: 清理 — custodian 合规巡检 + 死代码清理

---

## 4. 任务汇总

| # | 任务 | 负责人 | 状态 | 计划文件 |
|---|------|--------|------|----------|
| T0a | 全面代码库盘点 | researcher | done | .plans/dazi-app/researcher/research-full-audit/ |
| T0b | 现有代码深度审查 | reviewer | done | .plans/dazi-app/reviewer/review-full-audit/ |
| T1 | 前端+后端优化（安全/质量修复） | frontend-dev, backend-dev | done | .plans/dazi-app/frontend-dev/, backend-dev/ |
| T2 | 后端优化（安全修复+模块化导入） | backend-dev | done | .plans/dazi-app/backend-dev/ |
| T3 | E2E 测试关键流程 | e2e-tester | done | .plans/dazi-app/e2e-tester/ |
| T4 | 合规巡检 + 清理 | custodian | done | — |

---

## 5. 当前阶段

全部审查优化轮次（T0-T4）已完成。CI 全绿（Flutter 50/50 + Functions 31/31 + Golden Rules 0 WARN）。
E2E 覆盖 8 个 journey（J0-J7），T1 修复的 6 个关键安全/事务项均有 E2E 闭环。

---

## 6. 里程碑

### 2026-04-12 Glass Morph UI 全面升级完成

- **分支**: `feature/glass-morph-ui`
- **规格**: `docs/superpowers/specs/2026-04-12-glass-morph-ui-redesign.md`
- **计划**: `docs/superpowers/plans/2026-04-12-glass-morph-ui-redesign.md`
- **范围**: 21 个页面统一升级到 Glass Morph 深色优先双主题设计
- **交付**:
  - Phase 1 主题基础（Task 1-5）：`DaziColors` 配色 + `Spacing`/`Radii` tokens + `GlassTheme` InheritedWidget + 双亮度 ThemeData + `themeModeProvider`
  - Phase 2 通用组件（Task 6-14）：`GlowBackground` / `GlassCard` / `GlassButton` / `GlassInput` / `PillTag` / `AvatarStack` / `ShimmerSkeleton` / `AnimatedListItem` / `CelebrationOverlay`
  - Phase 3 导航（Task 15-16）：`HomeShell` BottomNavBar BackdropFilter 模糊 + `AppColors` 整体 deprecated
  - Phase 4 页面改造（Task 17-37）：21 个屏幕全部切换到 GlassTheme + 通用组件 + `AnimatedListItem` 交错动画
  - Phase 5 收尾（Task 38-40）：清理子 widget AppColors 残留 + CI 全绿 + 文档更新
- **CI**: 46/46 widget/unit 测试通过，`python scripts/run_ci.py` 全部 PASS
- **关键决策**: SD-5（见 CLAUDE.md 风格决策表）
