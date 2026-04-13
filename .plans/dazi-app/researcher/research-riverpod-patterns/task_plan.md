# research-riverpod-patterns · task_plan

## 目标
盘点 dazi-app Flutter 客户端（`client/lib/`）中现有的 Riverpod 使用模式，给后续 frontend-dev 新建 feature 提供统一的"风格基线"，避免多种写法并存。

## 范围
- **只读**：`client/lib/data/repositories/*.dart`（9 个仓库）
- **只读**：`client/lib/presentation/features/**/*.dart`（9 个 feature）
- **只读**：`client/lib/core/router/*.dart`

## 调研问题
1. Provider 类型分布（Provider / StateProvider / StateNotifierProvider / NotifierProvider / FutureProvider / StreamProvider / AsyncNotifierProvider / ChangeNotifierProvider / @riverpod codegen）
2. Repository 如何被注入？Firebase 客户端（Auth/Firestore/Functions/RTDB）是否走统一 provider
3. Feature 层 State 管理模式：ViewModel / Controller / freezed / AsyncValue
4. 一致性评分（STRONG / ADEQUATE / WEAK）
5. 产出"frontend-dev 新建 feature 时的 Riverpod 速查表"

## 交付物
- `task_plan.md`（本文件）
- `findings.md`（完整报告 + 基线速查）
- `progress.md`
- 在 `researcher/findings.md` 根索引追加一行

## 限制
- 只读，不改代码
- ≤ 400 行
- 中文撰写
