# task-storage-rules - 进度日志

## 2026-04-09

- 接到任务：P0 安全修复，创建 storage.rules。
- 用 Grep 在 client/ + functions/ 中搜索 Storage 使用关键字。
- 发现 Storage 仅在 Flutter 客户端两处使用：
  - `avatars/{uid}/{timestamp}.jpg`（step_name_avatar.dart）
  - `posts/{uid}/{timestamp}_{filename}`（post_create_repository.dart）
  - functions/ 未使用 Storage。
- **关键发现**：task 描述中"已知路径"与代码实际路径不符。team-lead 给的是 `users/{uid}/avatar/` 和 `posts/{postId}/images/`，实际是 `avatars/{uid}/` 和 `posts/{uid}/`。按实际路径写规则，并在 findings.md 中记录差异。
- **关键设计决策**：posts 路径不使用 firestore.get() 跨服务校验，因为上传时 Firestore doc 还不存在。改为约束 `auth.uid == 路径中的 userId`，同样安全。
- 创建 `storage.rules`（rules_version = '2'），包含：
  - 默认拒绝
  - avatars / posts 两条白名单
  - isSignedIn()、isImageUpload() 工具函数
  - 图片 ≤5MB、Content-Type image/*
- 修改 `firebase.json` 添加 `storage` 字段指向 `storage.rules`。
- 更新 `.plans/dazi-app/docs/invariants.md`：INV-1 状态改为"已存在 storage+firestore 双规则"，追加 INV-2a。
- 写完 task_plan.md、findings.md、progress.md。
- 在根 findings.md 追加索引条目。
- 在 findings.md 末尾加 [REVIEW-REQUEST] 标记，等待 team-lead 派 reviewer。
- 状态：**complete**，等待安全审查。
