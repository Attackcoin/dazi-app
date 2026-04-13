# research-algolia-client — Task Plan

## 范围
调研 Flutter 客户端接入 Algolia 搜索的可行方案,给 team-lead 一个明确推荐。
只读源代码,不改任何 client/ 或 functions/ 文件。

## 输入
- 后端同步代码: `functions/src/algoliaSync.js`(全量 141 行,已读)
- Flutter 依赖清单: `client/pubspec.yaml`(已读)
- 当前 Posts Repository: `client/lib/data/repositories/post_repository.dart`(已读)
- Home 首页: `client/lib/presentation/features/home/home_screen.dart`(已读)

## 调研问题
1. 对比 3 种方案:A) `algolia_helper_flutter` B) Firebase Function 代理 C) 手写 HTTP
2. 项目兼容性: Flutter/Dart 版本、现有 repo 模式、首页是否已有搜索入口
3. 安全与成本: Search-only key 暴露风险、免费额度、敏感字段保护
4. 明确推荐 + 落地步骤清单

## 产出
- `task_plan.md`(本文件)
- `findings.md` 完整报告
- `progress.md` 进度与状态
- 更新 researcher 根 `findings.md` 索引

## 限制
- 只读代码
- 中文
- 报告 ≤ 500 行
- 不实施,仅调研
