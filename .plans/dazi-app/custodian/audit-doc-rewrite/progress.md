# audit-doc-rewrite — 进度日志

## 2026-04-09

- [START] 接到 team-lead 任务：根据 researcher T0a 重写 docs/architecture.md 与 docs/api-contracts.md
- 读取 researcher/research-inventory/findings.md + decisions.md D3/D4/D5
- 扫描真理源头：
  - client/lib/data/models/{app_user,post,application,match,chat_message}.dart
  - client/lib/core/router/app_router.dart
  - client/pubspec.yaml
  - functions/src/{index,ai,applications,antiGhosting,deposits,notifications,algoliaSync}.js
  - functions/package.json
  - firestore.rules / firestore.indexes.json / firebase.json / storage.rules
- 重写 docs/architecture.md：10 个章节，含系统组件图 / 3 个业务流程 / D3 影响表
- 重写 docs/api-contracts.md：8 个集合全字段 + 23 个函数清单 + 索引 + Storage + 路由
- 更新 docs/index.md：section 导航 + 审计状态 [REWRITTEN by custodian]
- 追加 custodian/findings.md 根索引条目
- [COMPLETE] 交付 5 个文件修改 + 1 个索引追加
