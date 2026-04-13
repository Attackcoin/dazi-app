# review-storage-rules — 审查报告

**审查对象**：`storage.rules`（新增）、`firebase.json`（修改）
**审查日期**：2026-04-09
**审查者**：reviewer

## 判定

**[OK]**（附 2 [WARN]、2 [INFO]、1 [AUTOMATE]，不阻塞部署）

backend-dev 的规则是正确的"默认拒绝 + 最小放行"写法，路径与代码实际使用一致，越权/类型/大小都已约束。改进项为增强而非必需。

## 维度评分

| 维度 | 评级 | 说明 |
|---|---|---|
| RD-1 UI 精美度 | N/A | 安全规则，无 UI |
| RD-2 产品深度 | ADEQUATE | 覆盖未登录/越权/超大/非图片；SVG 子类型与多层路径有小缺口 |
| RD-3 Firebase 成本/性能 | STRONG | 默认 deny 防刷；5MB 合理；未引入 firestore.get() 额外读 |
| RD-4 测试覆盖 | WEAK（可接受） | 无 rules-unit-testing；规则极简可暂缓，列入 AUTOMATE |
| RD-5 可访问性/i18n | N/A | 不适用 |

RD-4 WEAK 与 CLAUDE.md 校准场景不同（规则刚落地、体量小、风险可控），用 AUTOMATE 跟进，整体仍判 [OK]。

## 路径覆盖核查

通过 Grep `client/lib` 与 `functions/src` 全量搜索 `firebase_storage`、`FirebaseStorage`、`putFile`、`putData`、`putString`、`uploadBytes`、`getStorage`、`.bucket(`、`listAll`：

| # | 调用点 | 路径 | 操作 | 覆盖？ |
|---|---|---|---|---|
| 1 | `client/lib/presentation/features/onboarding/widgets/step_name_avatar.dart:58-60` | `avatars/{uid}/{ts}.jpg` | putFile | ✓ |
| 2 | `client/lib/data/repositories/post_create_repository.dart:85-89` | `posts/{uid}/{ts}_{filename}` | putFile | ✓ |
| 3 | `client/lib/data/repositories/chat_repository.dart:33` | `chats/{chatId}/messages` | `_db.ref(...)` 是 **Realtime Database**，非 Storage | N/A |
| 4 | `functions/src/**` | — | 无 Storage 调用 | N/A |

无遗漏调用点；无 `listAll()`，默认 deny `{allPaths=**}` 不会误伤合法操作。

## 发现列表

### [INFO-1] getDownloadURL 与分享页兼容
`public/post.html:102` 通过 `<img src=...>` 渲染帖子图片。Storage 的 `getDownloadURL()` URL 带 `?alt=media&token=...`，**绕过 Storage Rules 的 read 约束**，所以 `read: if isSignedIn()` 不会阻断未登录访客看到图片。规则对分享场景无副作用。

（注：`post.html:127` 的 Firestore 读受 `firestore.rules:15` 限制——独立问题，不在本次范畴）

### [INFO-2] 不用 firestore.get() — 设计合理
Flutter 客户端先上传图片再写 Firestore post 文档，上传瞬间 Firestore 尚无对应文档。`auth.uid == 路径 userId` 既保证用户只能写进自己命名空间，又避免一次跨服务读（省费 + 降延迟）。**接受。**

长期可重构为 `posts/{postId}/{uid}/...` 支持级联删帖，应另立任务。

### [WARN-1] image/* 未排除 image/svg+xml
`isImageUpload()` 用 `contentType.matches('image/.*')` 放行所有 `image/` 子类型，含 `image/svg+xml`。SVG 可内嵌 `<script>`，download URL 被新标签页打开/`<object>` 嵌入/后端抓取处理时都可能暴露 XSS/SSRF 缺口。

**修复**（`storage.rules:14-18`）：
```diff
-      && request.resource.contentType.matches('image/.*');
+      && request.resource.contentType.matches('image/(jpeg|png|webp|gif|heic|heif)');
```

优先级：Medium。客户端走 `image_picker` 默认不选 SVG，但规则层应纵深防御。

**已由 team-lead 直接合入。**

### [WARN-2] {fileName} 单层匹配 — 长期兼容风险
`match /avatars/{userId}/{fileName}` 与 `/posts/{userId}/{fileName}` 只匹配单层。当前代码的确只有单层，无问题。

将来若加 `posts/{uid}/thumb/xxx.jpg` 等多层会静默 deny。**建议**：保持单层 + 加注释，或改为 `{fileName=**}`。

优先级：Low。延后处理。

### [AUTOMATE-1] 补 rules-unit-testing
"默认 deny + 两条白名单"最易回归。建议 custodian 把 4 个单测固化为 CI：越权写 / 伪造 uid / 超 5MB / 非 image。

优先级：Medium。不阻塞部署。

## 放行结论

**可以 `firebase deploy --only storage`**。WARN-1 已合入。WARN-2/AUTOMATE-1 作为独立跟进任务记录。
