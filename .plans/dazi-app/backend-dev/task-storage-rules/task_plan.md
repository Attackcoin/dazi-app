# task-storage-rules

> P0 安全修复：为 Firebase Storage 增加访问规则

## 背景
researcher 在 T0a 盘点时发现项目缺失 `storage.rules`，任意用户可读写他人文件。

## 实施清单

- [x] 1. 搜索代码确认 Storage 实际使用路径（client + functions）
- [x] 2. 编写 `storage.rules`（rules_version = '2'）
  - [x] 默认拒绝
  - [x] avatars/{userId}/{fileName} 路径规则
  - [x] posts/{userId}/{fileName} 路径规则
  - [x] 图片 ≤5MB 大小限制
  - [x] Content-Type 必须 image/*
- [x] 3. 更新 `firebase.json` 添加 `storage.rules` 引用
- [x] 4. 更新 `invariants.md`：INV-1 状态 + 追加 INV-2a
- [x] 5. 写 findings.md（发现、权衡、代码片段）
- [x] 6. 写 progress.md
- [x] 7. 在根 findings.md 索引追加一行
- [x] 8. findings.md 末尾加 [REVIEW-REQUEST]

## 验收
- [x] storage.rules 存在且语法合法（Storage Rules v2）
- [x] 规则覆盖代码中实际路径（avatars/, posts/）
- [x] firebase.json 正确引用
- [x] invariants.md 已更新
- [x] 任务文件夹三件套齐全
- [x] 根 findings.md 有索引条目
