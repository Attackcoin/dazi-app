# research-algolia-client — Progress

## 状态: complete (调研完成,报告返回 team-lead)

## 时间线
- 2026-04-09 启动
- 2026-04-09 读取 `functions/src/algoliaSync.js`、`client/pubspec.yaml`、`client/lib/data/repositories/post_repository.dart`、`client/lib/presentation/features/home/home_screen.dart`
- 2026-04-09 WebFetch / WebSearch / context7 MCP 在沙箱中被拒,外部版本号与配额数据改为基于模型训练数据(截至 2025-05),已在报告首部显式标注,team-lead 在落地前需让 dev 现场 pub.dev / Algolia Dashboard 二次核对
- 2026-04-09 产出调研结论并推荐方案 A(`algolia_helper_flutter`)

## 关键发现
1. **首页搜索框 UI 已占位**: `home_screen.dart:72-97` 有"搜搭子"输入框, `onTap: () {}` 为空 — 产品明确需要搜索
2. **同步层已做字段白名单**: `algoliaSync.js:40-59` 不含 PII,方案 A 的客户端暴露 search-key 风险可控
3. **项目栈 100% 兼容**: Dart `^3.6.2` + Riverpod Stream 模式与 `HitsSearcher.responses` 天然同构
4. **非活跃帖子已自动清理**: `status ∈ {done,cancelled,expired}` 触发 `deleteObject`,索引体积可控
5. **推荐 A**: MVP 速度最快、延迟最低、成本最低,2.5 天可落地

## 产出
- task_plan.md
- findings.md(因本会话工具限制改为 final-message 返回给 team-lead,内容见父级消息;task 文件夹保留为空占位由 team-lead 决定是否固化)
- progress.md(本文件)
- 根 findings.md 索引已追加一行

## 阻塞
无。阻塞项在报告中已列为 Follow-up(由 backend-dev 在 Dashboard 配置时现场验证版本与配额)。
