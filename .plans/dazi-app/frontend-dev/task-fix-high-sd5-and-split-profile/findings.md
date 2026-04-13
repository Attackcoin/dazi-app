# findings — task-fix-high-sd5-and-split-profile

## HIGH-1 SD-5 withOpacity 清理
- researcher 2026-04-13 报告 16 处/10 文件,但 baseline grep 当前已 0 处
- 根因:04-12→04-13 期间 commits 714b2f8 (remove AppColors) + 14a7553 (4 reviewer WARN) + 各 Glass Morph feat 已完整替换为 .withValues(alpha:)
- 本任务对 HIGH-1 无代码改动,仅验证 `grep -rn 'withOpacity(' client/lib` → 0 匹配

## HIGH-2 profile_screen 拆分
| 文件 | 拆分前 | 拆分后 |
|------|--------|--------|
| profile_screen.dart                  | 820 | 327 |
| profile_header.dart (新,part of)     | —   | 145 |
| profile_meta.dart   (新,part of)     | —   | 215 |
| profile_states.dart (新,part of)     | —   | 137 |
| profile_tabs.dart   (既有 part of)   | 248 | 248 |

### 改动清单
- `profile_screen.dart`
  - 新增 3 个 `part` 指令:profile_header/profile_meta/profile_states
  - 删除以下 private widget(移到 part 文件):
    - `_HeaderBackground` / `_SesameBadge` / `_Avatar` → `profile_header.dart`
    - `_MetaSection` / `_InfoChip` / `_StatsRow` / `_SectionTitle` → `profile_meta.dart`
    - `_EmptyState` / `_ErrorState` / `_ProfileSkeleton` / `_TabBarDelegate` → `profile_states.dart`
  - 保留:`ProfileScreen`(入口 widget)、`_ProfileView`(主状态 widget + settings sheet + 举报/拉黑菜单)
- 所有新文件首行 `part of 'profile_screen.dart';`,复用主文件的 import(glass_theme/glass_card/cached_network_image/go_router/AppUser 等)
- 零行为变更:class 定义逐字保留(仅位置迁移),Riverpod provider 依赖未触,SD-1~5 合规

### 为什么用 part 而不是独立 library
- 既有 `profile_tabs.dart` 已是 `part of 'profile_screen.dart'`,且它消费 `_ErrorState`/`_EmptyState`/`_SectionTitle` 等原 private 类
- 若改为独立 `import`,所有 `_Xxx` 必须提升为 public(破坏封装 + 扩散到 tabs)或写一个共享 `_profile_common.dart` part
- part 方案最小侵入、零破坏且与现状一致

## CI
- 基线:46/46 PASS
- 拆分后:46/46 PASS (api_contracts_sync / golden_rules / flutter_tests / functions_tests 全 PASS)

## 副作用/风险
- 无。纯代码移动,无签名变更,无 API/provider 变更,无 widget tree 变更
