# task-storage-rules — 发现

> P0 安全修复：补 Storage Rules
> 状态：complete（待 reviewer 审查）

## 关键发现：路径与 task 描述不符

team-lead 给的"已知路径"与代码实际路径**不一致**，规则按**代码实际路径**编写：

| 种类 | task 描述路径 | 代码实际路径 | 源文件 |
|---|---|---|---|
| 头像 | `users/{uid}/avatar/...` | `avatars/{uid}/{timestamp}.jpg` | `client/lib/presentation/features/onboarding/widgets/step_name_avatar.dart:58-60` |
| 帖子图片 | `posts/{postId}/images/...` | `posts/{uid}/{timestamp}_{filename}` | `client/lib/data/repositories/post_create_repository.dart:85-89` |

Cloud Functions 未使用 Storage。

## 关键设计决策

**posts 路径未使用 `firestore.get()` 跨服务校验 authorId**——因为 Flutter 客户端**先上传图片再写 Firestore post 文档**，上传时 Firestore 中还没有对应文档，无法 get。路径中的 `{userId}` 就是作者 uid，约束 `request.auth.uid == userId` 在当前架构下既正确又充分（用户只能在自己命名空间下写，无法伪造他人帖子图片）。

**建议路径重构**（非本任务范围）：将来统一到 `posts/{postId}/{uid}/{fileName}`，便于删帖级联清理，但需改客户端 + Functions 先分配 postId，应另立任务。

## storage.rules 完整内容

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function isSignedIn() { return request.auth != null; }
    function isImageUpload() {
      return request.resource != null
          && request.resource.size < 5 * 1024 * 1024
          && request.resource.contentType.matches('image/.*');
    }

    match /avatars/{userId}/{fileName} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && request.auth.uid == userId && isImageUpload();
    }

    match /posts/{userId}/{fileName} {
      allow read: if isSignedIn();
      allow write: if isSignedIn() && request.auth.uid == userId && isImageUpload();
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 防御能力

- 默认拒绝，所有未列路径匿名/登录都写不了
- 图片 ≤5MB，防刷配额
- Content-Type 必须 `image/*`，防上传可执行/恶意文档
- 写入必须 `auth.uid == 路径 userId`，防越权写他人目录
- 读取要求登录，防未登录爬虫列举桶内容

## 后续工作建议

1. `firebase deploy --only storage` 部署到生产
2. 用 `@firebase/rules-unit-testing` + storage emulator 写规则单测
3. 统一路径到 `posts/{postId}/...` 便于级联删除（另立任务）

## [REVIEW-REQUEST]

需要 reviewer 审查 `storage.rules` 安全性（P0 修复）。
