# 搭子 App — Glass Morph UI 全面升级设计文档

> 状态: APPROVED (brainstorm)
> 日期: 2026-04-12
> 范围: 全部 21 个页面统一升级

---

## 1. 设计方向总结

| 维度 | 决策 |
|------|------|
| 整体气质 | 活力潮流（小红书/Soul 风） |
| 视觉方案 | **Glass Morph 玻璃拟态** — 深色底 + 磨砂玻璃 + 彩色光斑 |
| 暗色基底 | 偏紫暖调（#0F0A1A → #1A1025） |
| 目标用户 | 20-35 核心，平衡趣味和实用 |
| 首页结构 | 双入口差异化：滑一滑=随机探索，发现=精准筛选 |
| PostCard 升级 | 新增发布者头像+昵称、参与者头像墙 |
| 动画程度 | 重度 — 每个操作都有视觉/触觉反馈 |
| 暗色模式 | 双色系设计，暗色为默认 |
| 品牌元素 | 图形 logo（抽象连接符号），国际化方向 |
| 改造范围 | 全部 21 个页面 |

---

## 2. 色彩系统

### 2.1 暗色模式（默认）

**背景画布：**

| Token | 色值 | 用途 |
|-------|------|------|
| `colorBase` | `#0F0A1A` | 页面最底层背景 |
| `colorSurface` | `#1A1025` | 主要内容区域背景 |
| `colorElevated` | `#241830` | 抬升面板（AppBar、BottomSheet header） |

**玻璃层级：**

| Token | 背景 | 边框 | 用途 |
|-------|------|------|------|
| `glassL1` | `rgba(255,255,255,0.04)` | `rgba(255,255,255,0.06)` | 卡片（PostCard、消息项） |
| `glassL2` | `rgba(255,255,255,0.08)` | `rgba(255,255,255,0.10)` | 浮层（Modal、BottomSheet、Popover） |
| `glassL3` | `rgba(255,255,255,0.12)` | `rgba(255,255,255,0.15)` | 输入框聚焦态、选中态 |

**强调色：**

| Token | 色值 | 发光阴影 | 用途 |
|-------|------|---------|------|
| `primary` | `#FF6B9D` | `rgba(255,107,157,0.3)` | 主操作按钮、选中态、品牌色 |
| `accent` | `#A855F7` | `rgba(168,85,247,0.3)` | 渐变终点、辅助高亮 |
| `info` | `#3B82F6` | `rgba(59,130,246,0.3)` | 信息提示、链接 |
| `success` | `#10B981` | `rgba(16,185,129,0.3)` | 成功状态、签到 |
| `warning` | `#F59E0B` | `rgba(245,158,11,0.3)` | 警告 |
| `error` | `#EF4444` | `rgba(239,68,68,0.3)` | 错误、危险操作 |

**渐变：**

| Token | 定义 | 用途 |
|-------|------|------|
| `heroGradient` | `linear(topLeft→bottomRight, #FF8A65, #FF6B9D, #A855F7)` | 主 CTA 按钮、发布按钮 |
| `cardGlowGradient` | `linear(135deg, rgba(255,107,157,0.2), rgba(168,85,247,0.2))` | 卡片图片区占位背景 |
| `accentGlowGradient` | `radial(center, primary@0.15, transparent@70%)` | 背景漂浮光斑 |

**文字：**

| Token | 色值 | 用途 |
|-------|------|------|
| `textPrimary` | `rgba(255,255,255,0.95)` | 标题、关键信息 |
| `textSecondary` | `rgba(255,255,255,0.70)` | 正文 |
| `textTertiary` | `rgba(255,255,255,0.40)` | 辅助说明、时间戳 |
| `textOnPrimary` | `#FFFFFF` | primary 按钮上的文字 |
| `textAccent` | `#FF8AB4` | 链接、可点击文字 |

### 2.2 亮色模式

**背景画布：**

| Token | 色值 | 用途 |
|-------|------|------|
| `colorBase` | `#F8F5FF` | 页面最底层（淡紫色调） |
| `colorSurface` | `#FFFFFF` | 主要内容区域 |
| `colorElevated` | `#FFFFFF` + `shadow(0,2,8,rgba(0,0,0,0.06))` | 抬升面板 |

**玻璃层级：**

| Token | 背景 | 边框 | 用途 |
|-------|------|------|------|
| `glassL1` | `rgba(255,255,255,0.70)` | `rgba(0,0,0,0.06)` + `shadow(0,2,8,rgba(0,0,0,0.04))` | 卡片 |
| `glassL2` | `rgba(255,255,255,0.85)` | `rgba(0,0,0,0.08)` + `shadow(0,4,16,rgba(0,0,0,0.06))` | 浮层 |
| `glassL3` | `rgba(255,255,255,0.95)` | `rgba(168,85,247,0.15)` + `shadow(0,2,8,rgba(168,85,247,0.08))` | 输入框聚焦态 |

**强调色：** 亮色模式强调色略加深以保证对比度。

| Token | 暗色值 | 亮色值 |
|-------|--------|--------|
| `primary` | `#FF6B9D` | `#FF6B9D`（不变） |
| `accent` | `#A855F7` | `#9333EA`（加深） |
| `info` | `#3B82F6` | `#2563EB`（加深） |

**文字：**

| Token | 色值 |
|-------|------|
| `textPrimary` | `rgba(0,0,0,0.90)` |
| `textSecondary` | `rgba(0,0,0,0.60)` |
| `textTertiary` | `rgba(0,0,0,0.35)` |

---

## 3. 核心组件设计

### 3.1 PostCard（信息流卡片）

**结构（自上而下）：**

1. **图片区**（高度 160px，圆角 20px 顶部）
   - 占位背景：`cardGlowGradient`
   - 分类标签浮在图片左上角：`glassL2` 背景 + 分类品牌色文字
   - 图片加载：`CachedNetworkImage` + shimmer 骨架
2. **内容区**（padding 14px）
   - **发布者行**：头像(28px, 渐变 border) + 昵称 + 时间戳
   - **标题**：`textPrimary`，最多 2 行，`titleMedium` + `fontWeight.w700`
   - **元信息行**：🕐 时间 + 📍 地点，`textTertiary`
   - **底部行**：参与者头像墙（最多 4 个 + `+N`）| 渐变"加入"按钮

**背景**：`glassL1`（暗色：4% white + 6% border；亮色：70% white + shadow）

**交互**：
- 点击 → 缩小 0.97 + 边框加亮 → 弹簧弹回（200ms）
- Hero 动画：图片区 → 详情页大图

### 3.2 底部导航栏

**结构：**
- 背景：`rgba(colorBase, 0.85)` + `BackdropFilter(blur: 20)`（真 blur，3 处之一）
- 顶部：1px `rgba(255,255,255,0.06)` 分隔线
- 5 个位置：滑一滑 | 发现 | [发布按钮] | 消息 | 我的
- 选中态：图标色 → `primary` + `drop-shadow` 发光 + 顶部光条（3px 高，primary 色，滑动过渡）
- 未选中态：`textTertiary`
- 中间发布按钮：48x48，`heroGradient`，`shadow(0,4,20,primary@0.4)`，2px `rgba(255,255,255,0.1)` border

**消息红点**：8x8 圆，`primary` 色 + `shadow(0,0,8,primary@0.5)` 发光效果

### 3.3 按钮系统

| 类型 | 背景 | 文字色 | 圆角 | 其他 |
|------|------|--------|------|------|
| Primary | `heroGradient` | white | 16px | `shadow(0,4,20,primary@0.35)` 发光 |
| Secondary | `rgba(primary,0.12)` | `textAccent` | 16px | 1px `rgba(primary,0.25)` border |
| Ghost | `glassL1` | `textSecondary` | 16px | 1px `rgba(255,255,255,0.1)` border |
| Danger | `rgba(error,0.12)` | `#F87171` | 16px | 1px `rgba(error,0.25)` border |

**微交互**：所有按钮按下 → 缩小 0.95 + 降亮（120ms, easeOut）→ 松开弹回 + 涟漪

### 3.4 Pill Tags（分类标签）

每个分类有自己的色调：
- 美食 🍜：primary 系
- 运动 🏀：accent 系
- 游戏 🎮：info 系
- 其他分类：从 primary/accent/info 中轮换

格式：`rgba(color,0.15)` 底 + `1px rgba(color,0.2)` border + color 文字

选中态：`rgba(color,0.25)` 底 + 更亮 border

### 3.5 输入框

| 状态 | 背景 | 边框 | Label 色 |
|------|------|------|---------|
| Normal | `glassL1` | `rgba(255,255,255,0.1)` | `textTertiary` |
| Focused | `rgba(primary,0.06)` | `rgba(primary,0.3)` + `shadow(0,0,12,primary@0.1)` | `textAccent` |
| Error | `rgba(error,0.06)` | `rgba(error,0.3)` | `error` |
| Disabled | `rgba(255,255,255,0.02)` | `rgba(255,255,255,0.04)` | `textTertiary@0.5` |

圆角：14px

### 3.6 聊天气泡

| 类型 | 背景 | 圆角 | 文字色 |
|------|------|------|--------|
| 他人消息 | `glassL1` | 4/16/16/16 (左上尖角) | `textSecondary` |
| 自己消息 | `linear(135deg, rgba(primary,0.2), rgba(accent,0.2))` + `1px rgba(primary,0.15)` border | 16/4/16/16 (右上尖角) | `textPrimary` |
| 系统消息 | `glassL1` 居中 pill | 10px | `textTertiary` |

他人消息带头像（28px） + 昵称。

### 3.7 骨架屏

- 形状与真实内容一致（卡片形、行形）
- 底色：`glassL1`
- Shimmer 光带：从左到右扫过，颜色 `rgba(255,255,255,0.06)`
- 周期：1500ms，linear，循环

---

## 4. 动画系统

### 4.1 层级 1：微交互（Micro）

| 动画 | 触发 | 参数 |
|------|------|------|
| 按钮按压 | onTapDown/Up | scale 0.95 → 1.0, 120ms, easeOut |
| 卡片按压 | onTapDown/Up | scale 0.97 → 1.0 + border 加亮, 200ms, spring(damping:15) |
| Tab 光条 | Tab 切换 | translateX 滑动, 250ms, easeInOut |
| Tab 图标 | Tab 切换 | 颜色渐变 + drop-shadow 渐显, 250ms |
| 触觉-轻触 | 按钮 tap | HapticFeedback.lightImpact |
| 触觉-滑卡阈值 | dx 跨过 100px | HapticFeedback.selectionClick |
| 触觉-成功 | 加入/签到成功 | HapticFeedback.mediumImpact |

### 4.2 层级 2：列表动画（List）

| 动画 | 参数 |
|------|------|
| 列表项入场 | 从下方 20px 淡入滑上, 350ms, easeOutCubic, 错位延迟 i*50ms |
| 骨架屏 shimmer | 光带左→右扫, 1500ms, linear, 循环 |
| 下拉刷新 | 自定义指示器：品牌 logo 旋转 + 逐渐放大, 阈值 80px |
| 空状态 | 图标上下浮动(8px, 2s周期) + 文字淡入 + 按钮弹入 |

**性能限制**：只有首次加载/刷新时有入场动画，滚动加载新项直接显示。

### 4.3 层级 3：页面转场（Page）

| 动画 | 参数 |
|------|------|
| Push 进入 | 新页右滑入 + 放大 0.95→1.0; 旧页左滑 + 缩小 1.0→0.95 + 降暗, 350ms, easeInOutCubic |
| Pop 返回 | 反向 push |
| Bottom Sheet | 磨砂背景淡入 + sheet 弹簧弹出, 400ms, spring |
| Hero 共享 | PostCard 图片→详情大图; 头像→Profile, 300ms, easeInOut |
| Tab 切换 | 横向滑动 + 淡入淡出, 250ms, 支持手势 |

### 4.4 层级 4：庆祝动画（Celebration）

| 场景 | 效果 | 时长 |
|------|------|------|
| 加入局成功 | 卡片飞出 + 粒子爆发 + ✓ 弹出 + 渐变光环扩散 | 900ms |
| 互评完成 | 星星逐个亮起弹跳 + 评分数字弹入 + 5星时 confetti | 1200ms |
| 签到成功 | GPS 锁定动画 + ✓ 弹出 + 脉冲波纹 + 短 confetti | 800ms |
| AI 回忆卡 | 卡片 3D 翻转 + 背景光斑流动 + 打字机效果 | 2000ms |

### 4.5 性能策略

1. **伪玻璃优先**：90% 的玻璃效果用 半透明底色 + 微弱边框 + BoxShadow，不用 BackdropFilter
2. **真 BackdropFilter 白名单**（仅 3 处）：BottomSheet overlay、Modal 弹层、底部导航栏
3. **动画开关**：检测 `MediaQuery.of(context).disableAnimations` + 低端机（`Platform.isAndroid` + 内存 < 4GB）自动降级：去粒子/confetti、减 blur sigma
4. **列表动画只首屏**：首次加载有入场动画，之后新增项直接显示
5. **Hero 白名单**：仅 PostCard→详情、头像→Profile 两个路径

---

## 5. 页面清单与升级要点

### 5.1 核心流程页面

| # | 页面 | 文件 | 升级要点 |
|---|------|------|---------|
| 1 | Splash | splash_screen.dart | 暗色底 + 品牌 logo 发光入场动画 |
| 2 | 登录 | login_screen.dart | Glass 输入框 + 渐变发送按钮 + 背景浮动光斑 |
| 3 | 验证码 | phone_verify_screen.dart | Glass 输入框 + 倒计时动画 |
| 4 | 引导(5步) | onboarding_screen.dart + step_*.dart | 每步有过渡动画 + 进度条发光 + glass 选择卡片 |
| 5 | 首页(滑一滑) | home_screen.dart | 背景光斑 + glass PostCard + 分类 pill 滚动条 |
| 6 | 滑卡 | swipe_screen.dart | 卡片发光边框 + 左滑/右滑方向指示 + 成功庆祝动画 |
| 7 | 发现 | discover_screen.dart | Glass 筛选栏 + 列表入场动画 + glass DiscoverCard |
| 8 | 搜索 | search_screen.dart | Glass 搜索框 + 结果列表入场 |
| 9 | 帖子详情 | post_detail_screen.dart | Hero 图片 + glass 信息面板 + 渐变加入按钮 + 参与者头像墙 |
| 10 | 发布帖子 | create_post_screen.dart | Glass 表单 + 分步指示器 + 发布成功庆祝 |

### 5.2 消息系统

| # | 页面 | 文件 | 升级要点 |
|---|------|------|---------|
| 11 | 消息列表 | messages_screen.dart | Glass 消息项 + 未读发光红点 + 列表入场 |
| 12 | 聊天 | chat_screen.dart | Glass/渐变气泡 + glass 输入栏 + 发送动画 |

### 5.3 活动流程

| # | 页面 | 文件 | 升级要点 |
|---|------|------|---------|
| 13 | 签到 | checkin_screen.dart | GPS 动画 + 签到成功庆祝（脉冲波纹 + confetti） |
| 14 | 评价 | review_screen.dart | Glass 评价卡 + 星星逐亮动画 |
| 15 | AI 回忆卡 | recap_card_screen.dart | 3D 翻转 + 打字机效果 + 光斑流动背景 |

### 5.4 个人中心

| # | 页面 | 文件 | 升级要点 |
|---|------|------|---------|
| 16 | 个人主页 | profile_screen.dart | Glass 头部卡片 + Tab 切换动画 + Hero 头像 |
| 17 | 编辑资料 | edit_profile_screen.dart | Glass 表单 + 头像上传动画 |
| 18 | 隐私设置 | privacy_settings_screen.dart | Glass 开关项 |
| 19 | 通知设置 | notifications_settings_screen.dart | Glass 开关项 |
| 20 | 黑名单 | blocked_users_screen.dart | Glass 列表项 |
| 21 | 紧急联系人 | emergency_contacts_screen.dart | Glass 列表项 |

### 5.5 通用壳

| 组件 | 文件 | 升级要点 |
|------|------|---------|
| 底部导航壳 | home_shell.dart | Glass 导航栏 + 光条 + 渐变发布按钮 |

---

## 6. 实现架构

### 6.1 新增/修改文件

```
client/lib/core/theme/
  app_colors.dart          ← 重写：改为 DaziColors 类，支持 light/dark 双 colorScheme
  app_theme.dart           ← 新增：ThemeData 工厂，统一 Material 3 token 映射
  glass_theme.dart         ← 新增：GlassTheme InheritedWidget，提供 glassL1/L2/L3 + 光斑参数

client/lib/core/widgets/
  glass_card.dart          ← 新增：通用 GlassCard widget（伪玻璃，接受 level: 1/2/3）
  glass_button.dart        ← 新增：4 种按钮变体
  glass_input.dart         ← 新增：3 态输入框
  pill_tag.dart            ← 新增：分类标签
  avatar_stack.dart        ← 新增：参与者头像墙
  shimmer_skeleton.dart    ← 新增：通用骨架屏
  animated_list_item.dart  ← 新增：列表入场动画包装器
  celebration_overlay.dart ← 新增：庆祝动画（粒子/confetti/脉冲）
```

### 6.2 主题切换策略

- 用 Flutter `ThemeMode.system` 跟随系统 + 手动切换
- `GlassTheme` 作为 InheritedWidget 包裹 MaterialApp，根据 brightness 提供对应 glass token
- 所有组件通过 `GlassTheme.of(context).glassL1` 取值，不硬编码

### 6.3 GlassCard 伪玻璃 vs 真 blur 决策表

| 场景 | 方式 | 理由 |
|------|------|------|
| PostCard / 消息项 / 列表项 | **伪玻璃**（Container + BoxDecoration：半透明底 + border + BoxShadow） | 列表中大量实例，BackdropFilter 会导致严重卡顿 |
| Bottom Sheet overlay | **真 blur**（BackdropFilter sigma:20） | 只有一个实例，且是模态遮罩 |
| Modal / Dialog overlay | **真 blur**（BackdropFilter sigma:16） | 同上，单实例模态 |
| 底部导航栏 | **真 blur**（BackdropFilter sigma:20） | 固定 1 个实例，不随列表滚动 |
| 输入框 / 按钮 / Pill tag | **伪玻璃** | 数量多，不需要真模糊 |
| AppBar | **伪玻璃** | 用固定半透明底色即可 |

`GlassCard` API 设计：
```dart
GlassCard({
  required int level,        // 1, 2, 3 对应三级透明度
  bool useBlur = false,      // 仅 BottomSheet/Modal/NavBar 传 true
  double blurSigma = 20.0,   // blur 强度
  Widget? child,
})
```

### 6.4 性能保障

- `GlassCard` 内部判断：默认伪玻璃（Container + BoxDecoration），`useBlur: true` 参数才启用 BackdropFilter
- 列表项动画用 `AnimatedListItem`，内部有 `_isFirstBuild` 标志，只首次触发
- `CelebrationOverlay` 用 `Overlay` 而不是 `Stack`，避免重建主 widget 树
- 低端机降级：检测 `SysInfo.getTotalPhysicalMemory() < 4GB`（Android）时，`useBlur` 全部强制 false，庆祝动画去掉粒子/confetti

---

## 7. 背景光斑系统

每个页面底层有 1-3 个漂浮光斑，营造 Glass Morph 氛围：

- **光斑 A**（粉色）：`radial-gradient(circle, rgba(255,107,157,0.15), transparent 70%)`，直径 200-300px
- **光斑 B**（紫色）：`radial-gradient(circle, rgba(168,85,247,0.12), transparent 70%)`，直径 150-250px
- **光斑 C**（蓝色，可选）：`radial-gradient(circle, rgba(59,130,246,0.08), transparent 70%)`

光斑位置固定（不随滚动），不同页面用不同位置组合避免单调。用 `Positioned` + `Container` 实现，零性能开销。

亮色模式：光斑透明度降到 0.06-0.08，更微妙。

---

## 8. 排版系统

| Token | 字号 | 字重 | 行高 | 用途 |
|-------|------|------|------|------|
| `displayLarge` | 28 | w700 | 1.2 | Splash 品牌名 |
| `headlineMedium` | 22 | w700 | 1.3 | 页面标题 |
| `titleLarge` | 18 | w600 | 1.3 | 区块标题 |
| `titleMedium` | 15 | w600 | 1.3 | PostCard 标题、聊天名 |
| `bodyLarge` | 15 | w400 | 1.5 | 正文 |
| `bodyMedium` | 13 | w400 | 1.5 | 次要正文 |
| `bodySmall` | 11 | w400 | 1.4 | 元信息（时间、地点） |
| `labelSmall` | 10 | w500 | 1.2 | 分类标签、badge |

字体：系统默认（iOS: SF Pro, Android: Roboto），不引入自定义字体（减小包体积）。

---

## 9. 间距系统

| Token | 值 | 用途 |
|-------|-----|------|
| `space4` | 4px | 紧凑间距（标签内） |
| `space8` | 8px | 小间距（行内元素） |
| `space12` | 12px | 中间距（卡片内组件间） |
| `space16` | 16px | 标准间距（section 间、列表项 padding） |
| `space20` | 20px | 大间距 |
| `space24` | 24px | 页面 padding |
| `space32` | 32px | 区块分隔 |

圆角：
- 卡片：20px
- 按钮：16px
- 输入框：14px
- Pill tag：12px
- 头像：50%（圆形）
- Bottom Sheet：24px（顶部）

---

## 10. 设计约束与规则

1. **颜色禁令**：禁止 `Color(0xFF...)` 硬编码，所有颜色必须通过 `DaziColors` 或 `GlassTheme` 取值
2. **间距禁令**：禁止 `SizedBox(height: 13.5)` 等非标值，必须用 `Spacing.spaceN` token
3. **玻璃一致性**：所有浮起容器必须用 `GlassCard(level: 1/2/3)`，不手动拼 Container
4. **动画一致性**：列表入场用 `AnimatedListItem`，按钮动画用 `GlassButton` 内置
5. **暗色优先**：设计和开发以暗色模式为基准，亮色模式作为派生
6. **可访问性**：文字对比度 ≥ 4.5:1，所有交互元素有 Semantics 标签
7. **性能红线**：BackdropFilter 不超过 3 处同时渲染
