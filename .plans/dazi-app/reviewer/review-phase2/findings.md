# review-phase2 — 阶段 2 前端精调合并审查

**Date:** 2026-04-09
**Reviewer:** reviewer (subagent,team-lead 转录)
**Scope:** T2b 发帖页 / T2c 详情页 / T2d 个人主页 / T2e 搜索页
**Final Verdict:** **[OK]**(首轮 5 WARN → team-lead 全部修复 → 复审 PASS)

---

## T2b 发帖页精调 — [WARN]

| # | 评分 | 说明 |
|---|------|------|
| RD-1 UI | STRONG | 颜色走 AppColors,间距 token,loading/骨架/空态完备 |
| RD-2 产品深度 | ADEQUATE | 三层异常分支覆盖主要场景,`_friendlyFirebaseError` 翻译 unavailable/network/permission/unauthenticated,`_publishing` 防抖正确 |
| RD-3 Firebase 成本 | ADEQUATE | 上传走 Storage,无 N+1 |
| RD-4 测试 | STRONG | 9 个单测全覆盖 `PostDraft.validate` 所有分支 |
| RD-5 可访问性 | STRONG | 添加/删除图片按钮有 Semantics,storage 依赖注入合规 |

**SD-1..SD-4**: 全 PASS

### W-T2b-1: `Future.wait` 缺 `eagerError: true`
- 文件: `client/lib/presentation/features/post/create_post_screen.dart:129`
- 默认 `eagerError: false`,多图并发上传时第 1 张失败仍会等全部完成才报错
- 修复: `await Future.wait(uploads, eagerError: true)`

---

## T2c 详情页精调 — [OK]

| # | 评分 | 说明 |
|---|------|------|
| RD-1 UI | STRONG | SliverAppBar + CachedNetworkImage + AppColors |
| RD-2 产品深度 | STRONG | 5 种 PostStatus 全覆盖 + `_notFound` 兜底 |
| RD-3 Firebase | ADEQUATE | postByIdProvider onSnapshot,无 N+1 |
| RD-4 测试 | ADEQUATE | 预先存在无测试,本任务未新增 |
| RD-5 可访问性 | ADEQUATE | 主按钮 Semantics,返回 tooltip |

**发现**: 无高置信度问题。

---

## T2d 个人主页精调 — [WARN]

| # | 评分 | 说明 |
|---|------|------|
| RD-1 UI | STRONG | 骨架屏 + 头部渐变 + CachedNetworkImage fallback + 三态齐全 |
| RD-2 产品深度 | ADEQUATE | 未登录/用户不存在/加载失败三态 fallback |
| RD-3 Firebase 成本 | ADEQUATE | 三个 StreamProvider.family 均 `limit(20)`,whereIn 30 上限有注释 |
| RD-4 测试 | ADEQUATE | 5 个 widget 测试 |
| RD-5 可访问性 | ADEQUATE | 昵称/头像/徽章 Semantics,按钮 tooltip |

**SD-1..SD-4**: 全 PASS
**文件大小**: profile_screen.dart 993 行,超 GR-1 WARN 阈值 (>800),未达 FAIL (>1200)

### W-T2d-1: `DefaultTabController` 冗余包裹
- 文件: `profile_screen.dart:115`
- `_ProfileViewState` 已手动 `_tab` controller 并显式绑定 TabBar/TabBarView,外层 DefaultTabController 是死代码
- 修复: 删除外层 DefaultTabController 包裹

### W-T2d-2: 他人主页 Tab 标签用第一人称"我"
- 文件: `profile_screen.dart:173-177`
- 浏览他人主页仍显示"我发布的/我申请的",语义错误
- 修复: 根据 `widget.isSelf` 动态切换,或统一改"发布的/申请的"

### W-T2d-3: `.withOpacity()` 弃用
- 文件: `profile_screen.dart:352, 667, 768, 844`
- Flutter 3.27+ 已弃用,post_detail_screen 已用 `.withValues(alpha:)` 新 API,不一致
- 修复: 全部替换为 `.withValues(alpha: x)`

### W-T2d-4: 测试名称与断言矛盾
- 文件: `client/test/presentation/features/profile/profile_screen_test.dart:103-143`
- 测试名为"自己视角"但断言 `find.byIcon(Icons.edit_outlined), findsNothing`,实际走的是 other 路径,isSelf=true 场景无真实覆盖
- 修复: 改测试名,或 override authStateProvider 为 FakeUser('self-uid') 补真正 self 测试

---

## T2e 搜索页 WARN 清理 — [OK]

| # | 评分 | 说明 |
|---|------|------|
| RD-1 UI | STRONG | resizeToAvoidBottomInset + viewInsets 动态补偿,四态完备 |
| RD-2 产品深度 | STRONG | debounce 300ms + 立即提交,清除 + 自动聚焦,空态"返回首页",error 重试 |
| RD-3 Firebase | ADEQUATE | 走 Algolia,StreamProvider.family 带 city 过滤 |
| RD-4 测试 | STRONG | 4 个 widget 测试覆盖 smoke/清除/loading/error |
| RD-5 可访问性 | STRONG | 搜索 icon + 清除按钮 Semantics |

**发现**: 无高置信度问题。

---

## 综合

- **BLOCK**: 无
- **首轮 WARN**: 5 项(1 在 T2b,4 在 T2d) — **全部已修复**

### 修复记录(team-lead 直改,2026-04-09)

| ID | 修复 |
|---|---|
| W-T2b-1 | `create_post_screen.dart:129` 加 `eagerError: true` |
| W-T2d-1 | 删除冗余 `DefaultTabController` 包裹 |
| W-T2d-2 | Tab 文案按 `widget.isSelf` 切换(我/TA) |
| W-T2d-3 | 4 处 `.withOpacity` → `.withValues(alpha:)` |
| W-T2d-4 | 重命名误导测试 + 新增真正 self 视角测试(FakeAuthUser) |

### 复审结果
reviewer 逐项核对 5 项 WARN 均 PASS,无新问题引入。**阶段 2 四任务全部 [OK],可合并。**
