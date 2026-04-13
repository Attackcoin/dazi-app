# research-riverpod-patterns — 调研报告

> 任务：盘点项目现有 Riverpod 用法 + 给后续 feature 一份风格基线
> 执行：researcher（阶段 1 T1e）
> 日期：2026-04-09
> 状态：complete

## 1. Provider 类型分布

全量 grep `client/lib/**/*.dart`（剔除 `CachedNetworkImageProvider` 噪声）：

| Provider 类型 | 次数 | 典型位置 |
|---|---|---|
| `Provider<T>(...)` | 9 | 9 个 `*RepositoryProvider` + `firebaseAuthProvider` + `firestoreProvider` + `firebaseFunctionsProvider` + `firebaseDatabaseProvider` |
| `StreamProvider<T>` | 3 | `authStateProvider`、`currentAppUserProvider`、`myMatchesProvider` |
| `StreamProvider.family<T,K>` | 6 | `feedProvider(FeedQuery)`、`postByIdProvider`、`matchByIdProvider`、`chatMessagesProvider`、`myApplicationForPostProvider`、`applicationsForPostProvider` |
| `FutureProvider[.family]` | 0 | — |
| `StateProvider` | 0 | — |
| `StateNotifierProvider` | 0 | — |
| `NotifierProvider`/`AsyncNotifierProvider` | 0 | — |
| `ChangeNotifierProvider` | 0 | — |
| `@riverpod` 注解（codegen） | 0 | — |

**结论**：只用两种 Provider — `Provider`（装仓库/SDK 单例）+ `StreamProvider[.family]`（监听 Firestore/RTDB 流）。零 Notifier / StateNotifier / freezed / codegen。

## 2. Repository 注入模式（9 个仓库全盘点）

| 文件 | 构造参数 | 依赖来源 |
|---|---|---|
| auth_repository | FirebaseAuth + FirebaseFirestore | `firebaseAuthProvider` + `firestoreProvider`（本文件定义） |
| application_repository | FirebaseFunctions + FirebaseFirestore | `firebaseFunctionsProvider`（本文件定义） + `firestoreProvider` |
| post_repository | FirebaseFirestore | `firestoreProvider` |
| match_repository | FirebaseFirestore | `firestoreProvider` |
| user_repository | FirebaseFirestore + FirebaseAuth | 两者 provider |
| post_create_repository | FirebaseFirestore + FirebaseAuth | 两者 provider；**但 `uploadImage()` 内直接 `FirebaseStorage.instance`** |
| chat_repository | FirebaseDatabase + FirebaseFirestore | `firebaseDatabaseProvider`（本文件定义） + `firestoreProvider` |
| checkin_repository | FirebaseFunctions | 从 `application_repository.dart` 导入 |
| review_repository | FirebaseFunctions | 同上 |

### 统一的 Firebase 客户端 Provider

| Provider | 定义位置 | 被谁用 |
|---|---|---|
| `firebaseAuthProvider` | `auth_repository.dart:9` | auth、user、post_create |
| `firestoreProvider` | `auth_repository.dart:10` | auth、application、post、match、user、post_create、chat |
| `firebaseFunctionsProvider` | `application_repository.dart:11` | application、checkin、review |
| `firebaseDatabaseProvider` | `chat_repository.dart:8` | chat |

### 观察
- **统一点**：9 个 repo 都走构造函数注入 + Provider，零 `.instance` 直接调用（除 Storage 一处）
- **弱点 1**：`firebaseFunctionsProvider` 定义在 `application_repository.dart`，被 checkin/review 跨文件 import — 职责错位
- **弱点 2**：`firestoreProvider` 定义在 `auth_repository.dart`，与 auth 无关
- **弱点 3**：`post_create_repository.dart:85` 的 `uploadImage()` 直接用 `FirebaseStorage.instance` — 全项目唯一 `.instance` 破口

## 3. State 管理模式（Feature 层）

**ViewModel/Controller 层完全没有**。grep `extends (StateNotifier|Notifier|AsyncNotifier|ChangeNotifier)` 零命中。

### UI 层写法
主流：`ConsumerStatefulWidget` + `ConsumerState` + `setState`（管本地 UI：筛选/表单）+ `ref.watch(xxxProvider)`（读数据）。少量纯展示屏用 `ConsumerWidget`。

### 异步状态承载
**全部用 `AsyncValue<T>`**（`StreamProvider` 原生返回）。无自定义 `{isLoading, error, data}`。所有 `.when()` / `.valueOrNull` 都指向 `AsyncValue`。

### freezed
**没有**。pubspec 无 freezed。唯一参数类 `FeedQuery`（`post_repository.dart:60`）手写 `==` 和 `hashCode`。

### 写操作
直接 `ref.read(xxxRepositoryProvider).doSomething()` + 本地 `setState(() => _loading = true)` + `ScaffoldMessenger` 提示错误。写状态耦合在 widget 内。

## 4. 一致性评分

**总体：ADEQUATE**

| 维度 | 评分 | 说明 |
|---|---|---|
| Provider 类型选择 | STRONG | 只有两种，零混用，无老 API |
| Repository 注入 | ADEQUATE | 9 个仓库统一；唯一破口 = `FirebaseStorage.instance` |
| Firebase provider 集中度 | WEAK | 4 个 SDK provider 散落在三个 repo 文件里 |
| Feature 层状态管理 | ADEQUATE | 风格完全一致；但缺 ViewModel/Notifier 层 |
| State 类建模 | ADEQUATE | 无 freezed，手写 `==` / `hashCode`；规模小可接受 |

没有"两套并存"分裂。两项小改进（firebase provider 位置 + Storage 破口）+ 一个决策缺口（是否引入 Notifier + freezed）。

## 5. frontend-dev 新建 feature 速查

> **基线原则：保持现状，不引入新范式**。MVP 阶段 Notifier / freezed / codegen 暂不引入。

### 5.1 Provider 选型

| 场景 | 用什么 |
|---|---|
| 包装 Repository / SDK 单例 | `Provider<T>(...)` |
| 监听 Firestore / RTDB 流 | `StreamProvider<T>` 或 `StreamProvider.family<T,K>` |
| 一次性 Cloud Function 调用 | **直接调 repo 方法**（`ref.read`），不为写操作建 FutureProvider |
| 纯本地 UI 状态（tab / 筛选 / 表单） | `ConsumerStatefulWidget` + `setState` |
| 禁用 | `StateProvider` / `ChangeNotifierProvider` / 自定义 isLoading 三件套 |

### 5.2 Repository 模板

```dart
// data/repositories/xxx_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart'; // 为拿 firestoreProvider

final xxxRepositoryProvider = Provider<XxxRepository>((ref) {
  return XxxRepository(firestore: ref.watch(firestoreProvider));
});

class XxxRepository {
  XxxRepository({required FirebaseFirestore firestore}) : _firestore = firestore;
  final FirebaseFirestore _firestore;
}

final xxxByIdProvider = StreamProvider.family<Xxx?, String>((ref, id) {
  return ref.watch(xxxRepositoryProvider).watchXxx(id);
});
```

### 5.3 UI 模板

```dart
class XxxScreen extends ConsumerStatefulWidget {
  const XxxScreen({super.key});
  @override
  ConsumerState<XxxScreen> createState() => _XxxScreenState();
}

class _XxxScreenState extends ConsumerState<XxxScreen> {
  String _filter = '';
  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(xxxProvider);
    return dataAsync.when(
      data: (list) => ListView(...),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败\n$e')),
    );
  }
}
```

### 5.4 写操作模板

```dart
Future<void> _submit() async {
  setState(() => _loading = true);
  try {
    await ref.read(xxxRepositoryProvider).doSomething();
    if (mounted) context.pop();
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('失败：$e')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

### 5.5 命名约定

| 对象 | 约定 | 示例 |
|---|---|---|
| Repository provider | `xxxRepositoryProvider` | `postRepositoryProvider` |
| Stream 数据 provider | `xxxProvider` / `xxxByIdProvider` / `xxxForYyyProvider` | `feedProvider`、`postByIdProvider` |
| Firebase SDK provider | `firebaseXxxProvider` / `firestoreProvider` | `firebaseAuthProvider` |
| 仓库类 | `XxxRepository` | `PostRepository` |
| Query 参数类 | `XxxQuery`（手写 `==` / `hashCode`） | `FeedQuery` |
| 本地 state 字段 | 前缀 `_` | `_category`、`_loading` |

### 5.6 禁忌
1. 禁止 repo 内 `FirebaseXxx.instance` — 必须构造注入。**唯一例外（技术债）**：`post_create_repository.uploadImage`
2. 禁止 `ChangeNotifier` / `StateProvider` / `StateNotifier`
3. 禁止自定义 `{isLoading, error, data}` — 统一 `AsyncValue<T>`
4. 禁止 UI 层 `FirebaseXxx.instance.collection(...)` — 走 repo

## 6. 技术债 / 决策建议

1. **TD-1**（小）：把 4 个 `firebaseXxxProvider` 迁到 `data/repositories/firebase_providers.dart`，消除职责错位
2. **TD-2**（小）：`post_create_repository.uploadImage` 改为构造注入 + 新增 `firebaseStorageProvider`
3. **DG-1**：多步骤写操作（发帖：上传图→写 Firestore→回调）或复杂表单时是否引入 `AsyncNotifier` + freezed？**MVP 建议维持 setState 风格**
4. **DG-2**：是否上 `@riverpod` codegen？**不建议**。手写 provider 仅 18 处，codegen 收益不值构建复杂度

## 7. 建议写入 CLAUDE.md 风格决策

| # | 决策 |
|---|------|
| SD-1 | Riverpod 仅 `Provider` + `StreamProvider[.family]`；不引 Notifier/StateNotifier/ChangeNotifier；UI 本地状态用 setState |
| SD-2 | Firebase SDK 客户端必须通过 `firebaseXxxProvider` 注入，禁止 `.instance` 直接调用 |
| SD-3 | 异步加载统一 `AsyncValue<T>` + `.when`，禁止自定义三件套 |
| SD-4 | MVP 阶段不引入 freezed / riverpod_generator |

## 8. 关键文件路径

- `client/lib/data/repositories/auth_repository.dart:9-10`（`firebaseAuthProvider` / `firestoreProvider` 定义）
- `client/lib/data/repositories/application_repository.dart:11`（`firebaseFunctionsProvider` — 位置错位）
- `client/lib/data/repositories/chat_repository.dart:8`（`firebaseDatabaseProvider` — 位置错位）
- `client/lib/data/repositories/post_create_repository.dart:85`（`FirebaseStorage.instance` 破口）
- `client/lib/presentation/features/home/home_screen.dart`（UI 风格样板）
- `client/lib/data/repositories/post_repository.dart:60-72`（`FeedQuery` 手写 `==` / `hashCode`）
