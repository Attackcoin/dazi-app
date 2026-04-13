# research-riverpod-patterns · progress

## 状态
complete

## 完成事项
- Grep 全量 Provider 类型在 `client/lib/` 的分布
- 读完 9 个 repository 文件，盘点 Firebase 客户端注入模式
- 抽样 6 个 feature（home/post/messages/review/checkin/onboarding）看 state 管理
- 验证 freezed / StateNotifier / AsyncNotifier / codegen 全部零使用
- 产出一致性评分 + frontend-dev 速查表 + 技术债清单

## 关键发现
- Provider 只用两种：`Provider` + `StreamProvider[.family]`
- 9 个 repo 全部走构造注入，唯一破口是 `post_create_repository.uploadImage` 的 `FirebaseStorage.instance`
- `firebaseFunctionsProvider` / `firebaseDatabaseProvider` / `firestoreProvider` 三个 SDK provider 职责错位定义在业务 repo 里
- Feature 层零 ViewModel/Notifier，UI 直接 ConsumerStatefulWidget + setState + AsyncValue.when
- 一致性评分：ADEQUATE（主流统一但有两项小问题）

## 未解决
- DG-1：何时升级到 AsyncNotifier + freezed（等 team-lead 在 post 功能精修时决策）
- DG-2：是否上 riverpod_generator（建议不上）

## 阻塞
无
