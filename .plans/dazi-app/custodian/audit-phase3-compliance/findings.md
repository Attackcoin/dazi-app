# audit-phase3-compliance - 发现报告

> Phase 3 合规巡检：规则合规 + 文件大小 + 不变量自动化 + 文档同步。
> 完成日期：2026-04-09

## 范围

- 规则：SD-1..SD-4（Riverpod 约束）、GR-1..GR-5（golden rules）、INV-7/INV-9（待自动化）
- 目录：`client/lib`、`functions/src`、`.plans/dazi-app/docs`

---

## 发现 1：GR-3 对 Firebase Functions 误报 `console.log`

**症状**：golden_rules.py GR-3 把 `functions/src/*.js` 里的 `console.log` 标为生产代码 warning。

**根因**：Firebase Functions 里 `console.log` 就是 Cloud Logging 的结构化日志入口，不是被遗忘的 debug 输出。检查脚本原本只排除了 `test/scripts/e2e` 等目录。

**修复**：`scripts/golden_rules.py` 新增 `SERVER_DIR_NAMES = {"functions"}` 白名单，在 `check_console_log` 中跳过 functions 子路径。

**状态**：complete

---

## 发现 2：SD-2 违规——`step_name_avatar.dart` 直连 FirebaseAuth/Storage

**症状**：`client/lib/presentation/features/onboarding/widgets/step_name_avatar.dart` 通过 `FirebaseAuth.instance.currentUser` 和 `FirebaseStorage.instance.ref(...)` 直接访问 Firebase 实例，违反 SD-2（必须走 provider 注入）。

**根因**：这个组件是早期写的 StatefulWidget，没有通过 `ConsumerStatefulWidget` + `firebaseXxxProvider` 注入。

**修复**：
- StatefulWidget → ConsumerStatefulWidget
- 移除 firebase_auth / firebase_storage 直接 import
- 添加 `auth_repository.dart` import（含 `firebaseAuthProvider` / `firebaseStorageProvider`）
- `_pickAvatar()` 中改用 `ref.read(firebaseAuthProvider).currentUser` 和 `ref.read(firebaseStorageProvider)`
- 局部变量 `ref` 与 `ConsumerState.ref` 冲突，重命名为 `ref0`

**状态**：complete

---

## 发现 3：GR-1 违规——`profile_screen.dart` 990 行

**症状**：client/lib/presentation/features/profile/profile_screen.dart 990 行，超过 GR-1 WARN 阈值 800。

**根因**：所有 Tab widgets（_MyPostsTab、_PostItem、_MyApplicationsTab、_ApplicationItem、_JoinedTab）内联在主屏文件中。

**修复**：使用 Dart `part` 机制将 Tab widgets 拆分到 `profile_tabs.dart`：
- 新文件：`client/lib/presentation/features/profile/profile_tabs.dart`（含 `part of 'profile_screen.dart';`）
- 从 profile_screen.dart 移除 _MyPostsTab、_PostItem、_postStatusLabel、_MyApplicationsTab、_ApplicationItem、_JoinedTab
- profile_screen.dart 990 → 743 行（低于 800）
- `_EmptyState` / `_ErrorState` / `_SectionTitle` 保留在主文件（两处都要用）——part file 天然可访问

**验证**：dart analyze 0 issues；6/6 profile tests 通过。

**状态**：complete

---

## 发现 4：GR-1 违规——`create_post_screen.dart` 837 行

**症状**：超 WARN 阈值 37 行。

**根因**：性别配额分区（_buildGenderQuotaSection + _quotaSlider）约 115 行内联在 `_CreatePostScreenState`。

**修复**：使用 `part of` + extension on `_CreatePostScreenState` 拆分：
- 新文件：`client/lib/presentation/features/post/create_post_quota.dart`
- `extension _GenderQuotaSection on _CreatePostScreenState { ... }` 包含两个 Widget 方法
- 文件顶部 `// ignore_for_file: invalid_use_of_protected_member` —— extension 调用 `setState` 会触发 protected 警告，但 part 文件与主 State 处于同一 library，语义等同类内调用
- create_post_screen.dart 837 → 724 行

**验证**：dart analyze 0 issues。

**状态**：complete

---

## 发现 5：INV-7 / INV-9 未自动化

**症状**：`docs/invariants.md` 中两条不变量标注"人工检查"：
- INV-7：颜色必须走 AppColors，禁止 `Color(0xFF...)` 硬编码
- INV-9：Algolia 凭证必须通过 `--dart-define` 注入

**修复**：扩展 `scripts/golden_rules.py`：
- 新增 **GR-6 硬编码颜色检查**（INV-7）：正则扫描 `Color\(0x[0-9A-Fa-f]{6,8}\)`，跳过 app_colors.dart / colors.dart / theme.dart（颜色源头）和测试目录
- 新增 **GR-7 Algolia 凭证检查**（INV-9）：检测 10 位大写 App ID 和 32 位 hex Key 字面量，**仅在 Algolia 上下文关键词（algolia/appid/searchkey/...）附近**触发以避免误报，跳过 `String.fromEnvironment` 合法注入
- 接入 `check_all()` 入口
- 更新 `docs/invariants.md`：INV-7 状态 → "已由 golden_rules.py GR-6 覆盖"；INV-9 状态 → "已由 golden_rules.py GR-7 覆盖"

**验证**：`python scripts/golden_rules.py client/lib functions/src --docs .plans/dazi-app/docs` → 0 FAIL/0 WARN，所有 7 条检查 OK。

**状态**：complete

---

## 发现 6：API 契约文档与代码漂移无自动化

**症状**：`docs/api-contracts.md §3 Cloud Functions` 是手工维护的函数清单，容易随代码演进而过期。没有自动化对账。

**修复**：新建 `scripts/check_api_contracts_sync.py`：
- 扫描 `functions/src/*.js`，提取 `exports.funcName = ...`（跳过 `_` 开头的内部函数）
- 解析 api-contracts.md §3 章节的表格**第一列**反引号函数名（用 `^\|\s*`(\w+)`\s*\|` 确保只匹配首列，避免把参数列里的 \`matchId\` 等误判）
- 报告 `MISSING_IN_DOCS`（代码有/文档无）和 `STALE_IN_DOCS`（文档有/代码无）
- 错误消息遵循智能体可读格式（`[CONTRACT-SYNC-*] + FIX:` 指令）
- 接入 `scripts/run_ci.py` 作为步骤 0/4

**验证**：识别到 23 个 exports，全部在文档中 → `[OK] 23 个函数，文档与代码一致`。

**状态**：complete

---

## 汇总

| # | 发现 | 状态 |
|---|------|------|
| 1 | GR-3 对 functions/ 误报 | complete |
| 2 | step_name_avatar.dart SD-2 违规 | complete |
| 3 | profile_screen.dart 990 行 → 743 | complete |
| 4 | create_post_screen.dart 837 行 → 724 | complete |
| 5 | INV-7 / INV-9 自动化（GR-6 / GR-7） | complete |
| 6 | API 契约同步检查脚本 | complete |

**CI 状态**：`python scripts/run_ci.py` → 4/4 PASS（api_contracts_sync / golden_rules / flutter_tests / functions_tests）。

**新增/变更文件**：
- 新增：`scripts/check_api_contracts_sync.py`
- 新增：`client/lib/presentation/features/profile/profile_tabs.dart`
- 新增：`client/lib/presentation/features/post/create_post_quota.dart`
- 修改：`scripts/golden_rules.py`（SERVER_DIR_NAMES、GR-6、GR-7）
- 修改：`scripts/run_ci.py`（api_contracts_sync 步骤）
- 修改：`client/lib/presentation/features/onboarding/widgets/step_name_avatar.dart`
- 修改：`client/lib/presentation/features/profile/profile_screen.dart`
- 修改：`client/lib/presentation/features/post/create_post_screen.dart`
- 修改：`.plans/dazi-app/docs/invariants.md`
