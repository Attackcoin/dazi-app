# task-post-polish — 进度

> 日期：2026-04-09
> 执行：team-lead 手动完成（子智能体 3 次 API 529 过载）
> 状态：complete

## 现状摘要（改前）

- `create_post_screen.dart` 772 行，表单字段、分类 pick、图片选择器（最多 6 张，maxWidth 1600 quality 85）、时间选择器、人数、费用、描述、社恐友好 toggle、AI 语音/生成描述 都已实现
- `PostCreateRepository` 已含 `validate()` 校验（分类/标题/时间/地点/人数/男女配额），`publish()` 写 Firestore
- TD-2（T1e 遗留）：`uploadImage()` 直接用 `FirebaseStorage.instance`，违反 SD-2
- 无错误类型区分，`catch (e)` 只 `发布失败：$e`
- 图片上传用 `Future.wait(_pendingImages.map(uploadImage))`，单张失败整体失败但不知道是哪张
- GestureDetector（添加图片/删除图片）无 Semantics
- 无任何单测 / widget 测试

## 改动清单

### TD-2 修复（SD-2 合规）

- `auth_repository.dart:11` 新增 `firebaseStorageProvider = Provider<FirebaseStorage>((_) => FirebaseStorage.instance)`
- `post_create_repository.dart:11-17` 构造参数加 `storage`
- `post_create_repository.dart:71-79` 字段 `_storage` 注入
- `post_create_repository.dart:85` `FirebaseStorage.instance.ref(...)` → `_storage.ref(...)`
- 项目全局 `FirebaseStorage.instance` 破口 = 0（grep 确认）

### RD-2 错误处理强化（create_post_screen.dart）

- `_publish()` 开头加 `if (_publishing) return;` debounce 防重复触发
- 图片上传改为逐张 wrap `.catchError((e) => throw _ImageUploadException(idx+1, e))`，失败时精确提示"第 N 张图片上传失败"
- `catch` 分三路：`FirebaseException` → `_friendlyFirebaseError`（按 code 映射 unavailable/network-request-failed/deadline-exceeded/permission-denied/unauthenticated 等中文提示），通用 `catch` → `_friendlyError`（检测 SocketException）
- 新增 `_ImageUploadException` 内部异常类
- 新增 `import firebase_core.dart` for FirebaseException

### RD-5 Semantics

- 添加图片按钮：`GestureDetector` 外包 `Semantics(button: true, label: "添加图片")`
- 删除图片按钮：`GestureDetector` 外包 `Semantics(button: true, label: "删除图片")`

### RD-4 测试

- 新建 `client/test/data/repositories/post_create_repository_test.dart`：9 个 `PostDraft.validate()` 测试用例
  - 完整通过 / 无分类 / 标题空 / 时间 null / 过去时间 / 地点空 / 人数 <2 / 男女配额超额 / 男女配额合理

## 未动项（明确延后）

- `Colors.white` 在 `_buildCategoryPicker` 选中态文字、publish 按钮 loading 圈、图片删除按钮 icon — 项目现有 widely 存在的 pattern，本次精调不做大面积替换
- 没有真正离线检测（connectivity_plus 未引入），依赖 Firebase 抛错
- 没有 widget smoke 测试 — 不引 mocktail/mockito，且依赖多 provider override 成本高
- `_showVoiceDialog` / `_generateDescription` AI 路径未加错误类型区分（AI 非关键路径）

## CI 结果

`python scripts/golden_rules.py client/lib functions/src --docs .plans/dazi-app/docs`
- 0 FAIL, 8 WARN（全是 functions/ 既有 console.log，T2b 零新增）, 0 INFO
- PASSED with warnings
- Flutter CLI 沙箱未安装，flutter test 跳过

## 自评

| RD | 评分 | 理由 |
|---|---|---|
| RD-1 | ADEQUATE | 表单精致度基本到位；残留 Colors.white 硬编码延后 |
| RD-2 | ADEQUATE+ | 错误类型区分 + 精确图片失败定位 + debounce 到位 |
| RD-3 | ADEQUATE | 图片已压缩 1600/85；6 张上限；debounce 防重复 |
| RD-4 | ADEQUATE | 9 个 PostDraft 单测；缺 widget 测试 |
| RD-5 | ADEQUATE | 图片添加/删除按钮 Semantics 补齐 |

SD-1..SD-4 全 PASS（尤其 SD-2：TD-2 已清理）。

## 可送审

是。
