# task-post-detail-polish — progress

**Status:** complete (manual implementation by team-lead)
**Owner:** team-lead (代 frontend-dev 执行，原因：API 529 导致子智能体派发 2 次失败)

## 完成内容

### 代码变更
- `client/lib/presentation/features/post/post_detail_screen.dart`
  - 删除 share 按钮（`onPressed: () {}` 空实现，MVP 未规划分享功能）
  - 为返回按钮添加 `tooltip: '返回'`（RD-5 accessibility）
  - `_ApplicantButtons` 状态机扩展：新增 `PostStatus.expired/cancelled/done` 3 个分支
    - expired → "活动已过期" + disabled
    - cancelled → "活动已取消" + disabled
    - done → "活动已结束" + disabled
  - 删除死按钮：左侧 `Icons.favorite_border` 按钮（`onPressed: () {}` 空实现），MVP 无收藏功能
  - 主按钮改为全宽，包裹 `Semantics(button, label, enabled)`（RD-5）

### 验证
- `dart analyze lib/presentation/features/post/post_detail_screen.dart` → No issues found
- flutter pub get 受 pubspec `algolia_helper_flutter ^0.7.0` 版本问题阻塞（既有问题，非本任务引入）

## 审查维度自评

| # | 维度 | 评级 | 说明 |
|---|------|------|------|
| RD-1 UI | ADEQUATE | 沿用已有 AppColors/token，按钮全宽更符合底部栏习惯 |
| RD-2 产品深度 | STRONG | 5 种 PostStatus 全覆盖，过期/取消/结束都有明确文案 |
| RD-3 成本/性能 | ADEQUATE | 无变化（沿用 `postByIdProvider`） |
| RD-4 测试 | WEAK | 未新增 widget test（T2c 接手时间紧迫；挂 backlog） |
| RD-5 可访问性 | ADEQUATE | 返回按钮有 tooltip，主操作有 Semantics |

## 未完成 / 挂起

- **TD-T2c-1**: post_detail_screen widget 测试缺失。状态机的 5 个分支需要 widget 测试覆盖（推荐用 `postByIdProvider.overrideWith` + `myApplicationForPostProvider.overrideWith`）
- 申请列表 sheet / 申请 sheet 本次未触及，如有问题留给专项任务
