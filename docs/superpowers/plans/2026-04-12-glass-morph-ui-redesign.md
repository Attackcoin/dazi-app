# Glass Morph UI 全面升级 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将搭子 App 全部 21 个页面从 Material 3 亮色风格升级为 Glass Morph 玻璃拟态双主题（暗色优先），包含完整的色彩系统、8 个通用组件、4 层动画体系。

**Architecture:** 底层建立 `GlassTheme` InheritedWidget 提供双主题 token，中层构建 8 个通用 widget（GlassCard/GlassButton/GlassInput 等），顶层逐页改造 21 个页面使用新组件。动画通过 AnimatedListItem 和 CelebrationOverlay 统一管理。

**Tech Stack:** Flutter 3.27 · Riverpod · go_router · CachedNetworkImage · HapticFeedback

**Design Spec:** `docs/superpowers/specs/2026-04-12-glass-morph-ui-redesign.md`

---

## 文件结构总览

### 新增文件

```
client/lib/core/theme/
  dazi_colors.dart              — 双主题色彩 token（替代 app_colors.dart）
  glass_theme.dart              — GlassTheme InheritedWidget + GlassThemeData
  spacing.dart                  — 间距/圆角 token 常量

client/lib/core/widgets/
  glass_card.dart               — 通用玻璃卡片（伪玻璃 / 真 blur 双模式）
  glass_button.dart             — 4 种按钮变体（Primary/Secondary/Ghost/Danger）
  glass_input.dart              — 3 态输入框
  pill_tag.dart                 — 分类标签
  avatar_stack.dart             — 参与者头像墙
  shimmer_skeleton.dart         — 通用骨架屏
  animated_list_item.dart       — 列表入场动画包装器
  celebration_overlay.dart      — 庆祝动画（粒子/confetti/脉冲）
  glow_background.dart          — 页面背景光斑

client/test/core/widgets/
  glass_card_test.dart
  glass_button_test.dart
  glass_input_test.dart
  pill_tag_test.dart
  avatar_stack_test.dart
```

### 修改文件

```
client/lib/core/theme/app_colors.dart  — 保留但标记 @deprecated，迁移期兼容
client/lib/core/theme/app_theme.dart   — 重写：双主题 ThemeData 工厂
client/lib/app.dart                    — 接入 GlassTheme + ThemeMode 切换

client/lib/presentation/features/      — 全部 21 个 *_screen.dart + home_shell.dart
```

---

## Phase 1：主题基础设施（Task 1-5）

### Task 1: DaziColors — 双主题色彩 token

**Files:**
- Create: `client/lib/core/theme/dazi_colors.dart`
- Test: `client/test/core/theme/dazi_colors_test.dart`

- [ ] **Step 1: 创建 dazi_colors.dart**

```dart
// client/lib/core/theme/dazi_colors.dart
import 'dart:ui';

/// 搭子 App Glass Morph 双主题色彩系统。
///
/// 使用方式：DaziColors.dark.primary / DaziColors.light.primary
/// 或通过 GlassTheme.of(context).colors 获取当前主题的颜色。
class DaziColorScheme {
  const DaziColorScheme._({
    required this.base,
    required this.surface,
    required this.elevated,
    required this.primary,
    required this.accent,
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.textAccent,
    required this.male,
    required this.female,
    required this.starColor,
    required this.glassL1Bg,
    required this.glassL1Border,
    required this.glassL2Bg,
    required this.glassL2Border,
    required this.glassL3Bg,
    required this.glassL3Border,
    required this.primaryGlow,
    required this.accentGlow,
    required this.infoGlow,
    required this.successGlow,
    required this.errorGlow,
  });

  // 背景画布
  final Color base;
  final Color surface;
  final Color elevated;

  // 强调色
  final Color primary;
  final Color accent;
  final Color info;
  final Color success;
  final Color warning;
  final Color error;

  // 文字
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnPrimary;
  final Color textAccent;

  // 性别 & 星评
  final Color male;
  final Color female;
  final Color starColor;

  // 玻璃层级
  final Color glassL1Bg;
  final Color glassL1Border;
  final Color glassL2Bg;
  final Color glassL2Border;
  final Color glassL3Bg;
  final Color glassL3Border;

  // 发光阴影
  final Color primaryGlow;
  final Color accentGlow;
  final Color infoGlow;
  final Color successGlow;
  final Color errorGlow;
}

class DaziColors {
  DaziColors._();

  static const dark = DaziColorScheme._(
    base: Color(0xFF0F0A1A),
    surface: Color(0xFF1A1025),
    elevated: Color(0xFF241830),
    primary: Color(0xFFFF6B9D),
    accent: Color(0xFFA855F7),
    info: Color(0xFF3B82F6),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    textPrimary: Color(0xF2FFFFFF),   // 95%
    textSecondary: Color(0xB3FFFFFF), // 70%
    textTertiary: Color(0x66FFFFFF),  // 40%
    textOnPrimary: Color(0xFFFFFFFF),
    textAccent: Color(0xFFFF8AB4),
    male: Color(0xFF3B82F6),
    female: Color(0xFFEC4899),
    starColor: Color(0xFFFFC107),
    glassL1Bg: Color(0x0AFFFFFF),     // 4%
    glassL1Border: Color(0x0FFFFFFF), // 6%
    glassL2Bg: Color(0x14FFFFFF),     // 8%
    glassL2Border: Color(0x1AFFFFFF), // 10%
    glassL3Bg: Color(0x1FFFFFFF),     // 12%
    glassL3Border: Color(0x26FFFFFF), // 15%
    primaryGlow: Color(0x4DFF6B9D),   // 30%
    accentGlow: Color(0x4DA855F7),
    infoGlow: Color(0x4D3B82F6),
    successGlow: Color(0x4D10B981),
    errorGlow: Color(0x4DEF4444),
  );

  static const light = DaziColorScheme._(
    base: Color(0xFFF8F5FF),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    primary: Color(0xFFFF6B9D),
    accent: Color(0xFF9333EA),
    info: Color(0xFF2563EB),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    textPrimary: Color(0xE6000000),   // 90%
    textSecondary: Color(0x99000000), // 60%
    textTertiary: Color(0x59000000),  // 35%
    textOnPrimary: Color(0xFFFFFFFF),
    textAccent: Color(0xFFD6336C),
    male: Color(0xFF2563EB),
    female: Color(0xFFDB2777),
    starColor: Color(0xFFF59E0B),
    glassL1Bg: Color(0xB3FFFFFF),     // 70%
    glassL1Border: Color(0x0F000000), // 6%
    glassL2Bg: Color(0xD9FFFFFF),     // 85%
    glassL2Border: Color(0x14000000), // 8%
    glassL3Bg: Color(0xF2FFFFFF),     // 95%
    glassL3Border: Color(0x26A855F7), // accent 15%
    primaryGlow: Color(0x33FF6B9D),   // 20%
    accentGlow: Color(0x339333EA),
    infoGlow: Color(0x332563EB),
    successGlow: Color(0x3310B981),
    errorGlow: Color(0x33EF4444),
  );

  // 共享渐变（不分主题）
  static const heroGradientColors = [Color(0xFFFF8A65), Color(0xFFFF6B9D), Color(0xFFA855F7)];
  static const cardGlowDarkColors = [Color(0x33FF6B9D), Color(0x33A855F7)];
  static const cardGlowLightColors = [Color(0x1AFF6B9D), Color(0x1AA855F7)];
}
```

- [ ] **Step 2: 写单元测试**

```dart
// client/test/core/theme/dazi_colors_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dazi_app/core/theme/dazi_colors.dart';

void main() {
  group('DaziColors', () {
    test('dark scheme has correct base color', () {
      expect(DaziColors.dark.base.value, 0xFF0F0A1A);
    });

    test('light scheme has correct base color', () {
      expect(DaziColors.light.base.value, 0xFFF8F5FF);
    });

    test('dark text primary is 95% white', () {
      expect(DaziColors.dark.textPrimary.alpha, closeTo(0xF2, 1));
    });

    test('light text primary is 90% black', () {
      expect(DaziColors.light.textPrimary.alpha, closeTo(0xE6, 1));
    });

    test('heroGradientColors has 3 stops', () {
      expect(DaziColors.heroGradientColors.length, 3);
    });

    test('dark glassL1Bg is 4% white', () {
      expect(DaziColors.dark.glassL1Bg.alpha, closeTo(0x0A, 1));
    });
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `cd C:\dazi-app\client && flutter test test/core/theme/dazi_colors_test.dart`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add client/lib/core/theme/dazi_colors.dart client/test/core/theme/dazi_colors_test.dart
git commit -m "feat(theme): add DaziColors dual-theme color system"
```

---

### Task 2: Spacing — 间距与圆角 token

**Files:**
- Create: `client/lib/core/theme/spacing.dart`

- [ ] **Step 1: 创建 spacing.dart**

```dart
// client/lib/core/theme/spacing.dart

/// 搭子 App 间距系统。所有间距必须使用这些 token，禁止硬编码数值。
class Spacing {
  Spacing._();

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
}

/// 搭子 App 圆角系统。
class Radii {
  Radii._();

  static const double card = 20;
  static const double button = 16;
  static const double input = 14;
  static const double pill = 12;
  static const double sheet = 24;
  // 头像用 50%，在代码中用 CircleAvatar 或 borderRadius: height/2
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/theme/spacing.dart
git commit -m "feat(theme): add Spacing and Radii token constants"
```

---

### Task 3: GlassTheme — InheritedWidget 主题分发

**Files:**
- Create: `client/lib/core/theme/glass_theme.dart`

- [ ] **Step 1: 创建 glass_theme.dart**

```dart
// client/lib/core/theme/glass_theme.dart
import 'package:flutter/material.dart';

import 'dazi_colors.dart';

/// Glass Morph 主题数据，通过 [GlassTheme.of(context)] 获取。
class GlassThemeData {
  const GlassThemeData({
    required this.colors,
    required this.isDark,
  });

  final DaziColorScheme colors;
  final bool isDark;

  /// 根据 level (1/2/3) 返回对应的玻璃背景色。
  Color glassBackground(int level) {
    switch (level) {
      case 1: return colors.glassL1Bg;
      case 2: return colors.glassL2Bg;
      case 3: return colors.glassL3Bg;
      default: return colors.glassL1Bg;
    }
  }

  /// 根据 level (1/2/3) 返回对应的玻璃边框色。
  Color glassBorder(int level) {
    switch (level) {
      case 1: return colors.glassL1Border;
      case 2: return colors.glassL2Border;
      case 3: return colors.glassL3Border;
      default: return colors.glassL1Border;
    }
  }

  /// 卡片图片区占位渐变色。
  List<Color> get cardGlowColors =>
      isDark ? DaziColors.cardGlowDarkColors : DaziColors.cardGlowLightColors;

  static const dark = GlassThemeData(colors: DaziColors.dark, isDark: true);
  static const light = GlassThemeData(colors: DaziColors.light, isDark: false);
}

/// 提供 [GlassThemeData] 给子树。
class GlassTheme extends InheritedWidget {
  const GlassTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final GlassThemeData data;

  static GlassThemeData of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<GlassTheme>();
    assert(widget != null, 'No GlassTheme found in context');
    return widget!.data;
  }

  @override
  bool updateShouldNotify(GlassTheme oldWidget) => data != oldWidget.data;
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/theme/glass_theme.dart
git commit -m "feat(theme): add GlassTheme InheritedWidget"
```

---

### Task 4: AppTheme 重写 — 双主题 ThemeData

**Files:**
- Modify: `client/lib/core/theme/app_theme.dart`

- [ ] **Step 1: 重写 app_theme.dart**

```dart
// client/lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

import 'dazi_colors.dart';
import 'spacing.dart';

/// 搭子 App Material ThemeData 工厂。
///
/// 使用 [AppTheme.dark] 和 [AppTheme.light] 获取对应主题。
/// Glass Morph 特有属性（玻璃层级等）通过 [GlassTheme] 获取。
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(DaziColors.dark, Brightness.dark);
  static ThemeData get light => _build(DaziColors.light, Brightness.light);

  static ThemeData _build(DaziColorScheme c, Brightness brightness) {
    final textTheme = TextTheme(
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.3),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.3),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.3),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: c.textPrimary, height: 1.5),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: c.textSecondary, height: 1.5),
      bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: c.textTertiary, height: 1.4),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.textTertiary, height: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.textOnPrimary,
        secondary: c.accent,
        onSecondary: c.textOnPrimary,
        error: c.error,
        onError: c.textOnPrimary,
        surface: c.surface,
        onSurface: c.textPrimary,
      ),
      scaffoldBackgroundColor: c.base,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.elevated.withOpacity(0.85),
        foregroundColor: c.textPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: c.textPrimary,
        ),
      ),
      cardTheme: CardTheme(
        color: c.glassL1Bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: c.glassL1Border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: c.glassL1Border,
        thickness: 0.5,
        space: 0.5,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/theme/app_theme.dart
git commit -m "refactor(theme): rewrite AppTheme for dark/light dual themes"
```

---

### Task 5: app.dart — 接入 GlassTheme + 暗色模式

**Files:**
- Modify: `client/lib/app.dart`

- [ ] **Step 1: 修改 app.dart**

```dart
// client/lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/glass_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/push_notification_service.dart';

/// 主题模式 Provider — 默认跟随系统。
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class DaziApp extends ConsumerStatefulWidget {
  const DaziApp({super.key});

  @override
  ConsumerState<DaziApp> createState() => _DaziAppState();
}

class _DaziAppState extends ConsumerState<DaziApp> {
  bool _fcmInitialized = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // 登录后初始化 FCM
    ref.listen(authStateProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null && !_fcmInitialized) {
        _fcmInitialized = true;
        ref.read(pushNotificationServiceProvider).initialize();
      }
      if (user == null) {
        _fcmInitialized = false;
      }
    });

    return _GlassThemeWrapper(
      themeMode: themeMode,
      child: MaterialApp.router(
        title: '搭子',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
      ),
    );
  }
}

/// 根据实际 brightness 注入对应 GlassThemeData。
class _GlassThemeWrapper extends StatelessWidget {
  const _GlassThemeWrapper({required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 在 MaterialApp 外层，没有 Theme.of(context)，需要自行判断
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    return GlassTheme(
      data: isDark ? GlassThemeData.dark : GlassThemeData.light,
      child: child,
    );
  }
}
```

- [ ] **Step 2: 验证编译通过**

Run: `cd C:\dazi-app\client && flutter analyze --no-fatal-infos`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add client/lib/app.dart
git commit -m "feat(app): integrate GlassTheme + dark mode support"
```

---

## Phase 2：通用组件库（Task 6-14）

### Task 6: GlowBackground — 页面背景光斑

**Files:**
- Create: `client/lib/core/widgets/glow_background.dart`

- [ ] **Step 1: 创建 glow_background.dart**

```dart
// client/lib/core/widgets/glow_background.dart
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 页面背景光斑容器。在 [child] 底层放置 1-3 个径向渐变光斑。
///
/// 光斑位置固定（不随滚动），用 [Positioned] + [Container] 实现，零性能开销。
class GlowBackground extends StatelessWidget {
  const GlowBackground({
    super.key,
    required this.child,
    this.globs = const [GlowGlob.topRight, GlowGlob.bottomLeft],
  });

  final Widget child;
  final List<GlowGlob> globs;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final opacity = gt.isDark ? 1.0 : 0.5; // 亮色模式光斑减弱

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: gt.colors.base),
        ),
        for (final glob in globs)
          Positioned(
            top: glob.top,
            bottom: glob.bottom,
            left: glob.left,
            right: glob.right,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: glob.size,
                height: glob.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glob.color, glob.color.withOpacity(0)],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

/// 预定义光斑配置。
class GlowGlob {
  const GlowGlob({
    required this.color,
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final Color color;
  final double size;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;

  static const topRight = GlowGlob(
    color: Color(0x26FF6B9D), // primary 15%
    size: 280,
    top: -60,
    right: -60,
  );

  static const bottomLeft = GlowGlob(
    color: Color(0x1FA855F7), // accent 12%
    size: 220,
    bottom: 100,
    left: -40,
  );

  static const centerBlue = GlowGlob(
    color: Color(0x143B82F6), // info 8%
    size: 200,
    top: 300,
    right: 20,
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/glow_background.dart
git commit -m "feat(widgets): add GlowBackground page backdrop"
```

---

### Task 7: GlassCard — 通用玻璃卡片

**Files:**
- Create: `client/lib/core/widgets/glass_card.dart`
- Test: `client/test/core/widgets/glass_card_test.dart`

- [ ] **Step 1: 创建 glass_card.dart**

```dart
// client/lib/core/widgets/glass_card.dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// Glass Morph 玻璃卡片。
///
/// 默认使用伪玻璃（半透明底色 + 边框 + BoxShadow）。
/// 仅 BottomSheet/Modal/NavBar 传 [useBlur: true] 启用真 BackdropFilter。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.level = 1,
    this.useBlur = false,
    this.blurSigma = 20.0,
    this.borderRadius,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final int level;
  final bool useBlur;
  final double blurSigma;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final bg = gt.glassBackground(level);
    final border = gt.glassBorder(level);
    final radius = borderRadius ?? BorderRadius.circular(Radii.card);

    Widget content = Container(
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: useBlur ? bg.withOpacity(bg.opacity * 0.5) : bg,
        borderRadius: radius,
        border: Border.all(color: border, width: 1),
        boxShadow: gt.isDark
            ? null
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );

    if (useBlur) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      );
    }

    return content;
  }
}
```

- [ ] **Step 2: 写 widget 测试**

```dart
// client/test/core/widgets/glass_card_test.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazi_app/core/widgets/glass_card.dart';
import 'package:dazi_app/core/theme/glass_theme.dart';

void main() {
  Widget wrap(Widget child, {bool isDark = true}) {
    return MaterialApp(
      home: GlassTheme(
        data: isDark ? GlassThemeData.dark : GlassThemeData.light,
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('GlassCard renders child', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(child: Text('hello')),
    ));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('GlassCard without blur has no BackdropFilter', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(child: SizedBox()),
    ));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('GlassCard with useBlur has BackdropFilter', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(useBlur: true, child: SizedBox()),
    ));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('GlassCard onTap fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(
      GlassCard(onTap: () => tapped = true, child: const Text('tap me')),
    ));
    await tester.tap(find.text('tap me'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `cd C:\dazi-app\client && flutter test test/core/widgets/glass_card_test.dart`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add client/lib/core/widgets/glass_card.dart client/test/core/widgets/glass_card_test.dart
git commit -m "feat(widgets): add GlassCard with fake/real blur modes"
```

---

### Task 8: GlassButton — 4 种按钮变体

**Files:**
- Create: `client/lib/core/widgets/glass_button.dart`
- Test: `client/test/core/widgets/glass_button_test.dart`

- [ ] **Step 1: 创建 glass_button.dart**

```dart
// client/lib/core/widgets/glass_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dazi_colors.dart';
import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

enum GlassButtonVariant { primary, secondary, ghost, danger }

/// Glass Morph 按钮。按下缩小 0.95 + 触觉反馈。
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    lowerBound: 0.95,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _scaleCtrl.reverse();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) => _scaleCtrl.forward();
  void _onTapCancel() => _scaleCtrl.forward();

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final c = gt.colors;
    final enabled = widget.onPressed != null && !widget.isLoading;

    Color bg;
    Color fg;
    Border? border;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case GlassButtonVariant.primary:
        bg = Colors.transparent; // 渐变由 gradient 处理
        fg = c.textOnPrimary;
        shadows = [BoxShadow(color: c.primaryGlow, blurRadius: 20, offset: const Offset(0, 4))];
      case GlassButtonVariant.secondary:
        bg = c.primary.withOpacity(0.12);
        fg = c.textAccent;
        border = Border.all(color: c.primary.withOpacity(0.25));
      case GlassButtonVariant.ghost:
        bg = c.glassL1Bg;
        fg = c.textSecondary;
        border = Border.all(color: c.glassL1Border);
      case GlassButtonVariant.danger:
        bg = c.error.withOpacity(0.12);
        fg = const Color(0xFFF87171);
        border = Border.all(color: c.error.withOpacity(0.25));
    }

    final isPrimary = widget.variant == GlassButtonVariant.primary;

    return ScaleTransition(
      scale: _scaleCtrl,
      child: GestureDetector(
        onTapDown: enabled ? _onTapDown : null,
        onTapUp: enabled ? _onTapUp : null,
        onTapCancel: enabled ? _onTapCancel : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
            decoration: BoxDecoration(
              color: isPrimary ? null : bg,
              gradient: isPrimary
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: DaziColors.heroGradientColors,
                    )
                  : null,
              borderRadius: BorderRadius.circular(Radii.button),
              border: border,
              boxShadow: enabled ? shadows : null,
            ),
            child: Row(
              mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.space8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    ),
                  )
                else if (widget.icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: Spacing.space8),
                    child: Icon(widget.icon, size: 18, color: fg),
                  ),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 写 widget 测试**

```dart
// client/test/core/widgets/glass_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dazi_app/core/widgets/glass_button.dart';
import 'package:dazi_app/core/theme/glass_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: GlassTheme(
        data: GlassThemeData.dark,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('GlassButton shows label', (tester) async {
    await tester.pumpWidget(wrap(
      GlassButton(label: '加入', onPressed: () {}),
    ));
    expect(find.text('加入'), findsOneWidget);
  });

  testWidgets('GlassButton onPressed fires', (tester) async {
    var pressed = false;
    await tester.pumpWidget(wrap(
      GlassButton(label: 'tap', onPressed: () => pressed = true),
    ));
    await tester.tap(find.text('tap'));
    expect(pressed, isTrue);
  });

  testWidgets('GlassButton disabled when onPressed is null', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassButton(label: 'disabled', onPressed: null),
    ));
    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0.5);
  });

  testWidgets('GlassButton shows loading indicator', (tester) async {
    await tester.pumpWidget(wrap(
      GlassButton(label: 'loading', onPressed: () {}, isLoading: true),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `cd C:\dazi-app\client && flutter test test/core/widgets/glass_button_test.dart`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add client/lib/core/widgets/glass_button.dart client/test/core/widgets/glass_button_test.dart
git commit -m "feat(widgets): add GlassButton with 4 variants + scale animation"
```

---

### Task 9: GlassInput — 3 态输入框

**Files:**
- Create: `client/lib/core/widgets/glass_input.dart`

- [ ] **Step 1: 创建 glass_input.dart**

```dart
// client/lib/core/widgets/glass_input.dart
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// Glass Morph 输入框。3 态：Normal / Focused（粉色发光边框）/ Error。
class GlassInput extends StatelessWidget {
  const GlassInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final c = gt.colors;
    final hasError = errorText != null && errorText!.isNotEmpty;

    // 颜色根据错误态切换
    final focusBorderColor = hasError ? c.error.withOpacity(0.3) : c.primary.withOpacity(0.3);
    final focusBgColor = hasError ? c.error.withOpacity(0.06) : c.primary.withOpacity(0.06);
    final labelColor = hasError ? c.error : c.textAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.space4, left: Spacing.space4),
            child: Text(label!, style: TextStyle(fontSize: 12, color: c.textTertiary)),
          ),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          style: TextStyle(color: c.textPrimary, fontSize: 14),
          cursorColor: c.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: c.textTertiary),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: c.glassL1Bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.glassL1Border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.glassL1Border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: focusBorderColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.error.withOpacity(0.3)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.input),
              borderSide: BorderSide(color: c.error.withOpacity(0.5), width: 1.5),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.space4, left: Spacing.space4),
            child: Text(errorText!, style: TextStyle(fontSize: 11, color: c.error)),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/glass_input.dart
git commit -m "feat(widgets): add GlassInput with 3-state theming"
```

---

### Task 10: PillTag — 分类标签

**Files:**
- Create: `client/lib/core/widgets/pill_tag.dart`

- [ ] **Step 1: 创建 pill_tag.dart**

```dart
// client/lib/core/widgets/pill_tag.dart
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import '../theme/spacing.dart';

/// Glass Morph 分类标签 pill。
class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final c = color ?? gt.colors.primary;
    final bgOpacity = selected ? 0.25 : 0.15;
    final borderOpacity = selected ? 0.35 : 0.2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.space12, vertical: 5),
        decoration: BoxDecoration(
          color: c.withOpacity(bgOpacity),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.withOpacity(borderOpacity)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: c,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/pill_tag.dart
git commit -m "feat(widgets): add PillTag category chip"
```

---

### Task 11: AvatarStack — 参与者头像墙

**Files:**
- Create: `client/lib/core/widgets/avatar_stack.dart`

- [ ] **Step 1: 创建 avatar_stack.dart**

```dart
// client/lib/core/widgets/avatar_stack.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/dazi_colors.dart';
import '../theme/glass_theme.dart';

/// 重叠头像墙，最多显示 [maxVisible] 个头像 + "+N" 溢出提示。
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.avatarUrls,
    this.size = 24,
    this.overlap = 8,
    this.maxVisible = 4,
    this.borderWidth = 2,
  });

  final List<String> avatarUrls;
  final double size;
  final double overlap;
  final int maxVisible;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final borderColor = gt.isDark ? gt.colors.glassL1Border : Colors.white;
    final visibleCount = avatarUrls.length > maxVisible ? maxVisible : avatarUrls.length;
    final overflow = avatarUrls.length - maxVisible;

    return SizedBox(
      height: size,
      width: visibleCount * (size - overlap) + overlap + (overflow > 0 ? (size - overlap) + overlap : 0),
      child: Stack(
        children: [
          for (var i = 0; i < visibleCount; i++)
            Positioned(
              left: i * (size - overlap),
              child: _Avatar(
                url: avatarUrls[i],
                size: size,
                borderWidth: borderWidth,
                borderColor: borderColor,
                index: i,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visibleCount * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gt.colors.glassL1Bg,
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: gt.colors.textTertiary,
                    fontSize: size * 0.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.size,
    required this.borderWidth,
    required this.borderColor,
    required this.index,
  });

  final String url;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final int index;

  // 给没有头像的用户用的渐变 fallback
  static const _fallbackGradients = [
    [Color(0xFFFF6B9D), Color(0xFFFF8A65)],
    [Color(0xFFA855F7), Color(0xFF6366F1)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF34D399)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _fallbackGradients[index % _fallbackGradients.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/avatar_stack.dart
git commit -m "feat(widgets): add AvatarStack overlapping avatar wall"
```

---

### Task 12: ShimmerSkeleton — 通用骨架屏

**Files:**
- Create: `client/lib/core/widgets/shimmer_skeleton.dart`

- [ ] **Step 1: 创建 shimmer_skeleton.dart**

```dart
// client/lib/core/widgets/shimmer_skeleton.dart
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// Glass Morph 骨架屏。光带从左到右扫过，1500ms 循环。
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final baseColor = gt.colors.glassL1Bg;
    final shimmerColor = gt.isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.8);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: baseColor,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _ctrl.value, 0),
              end: Alignment(-0.5 + 2.0 * _ctrl.value, 0),
              colors: [baseColor, shimmerColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/shimmer_skeleton.dart
git commit -m "feat(widgets): add ShimmerSkeleton loading placeholder"
```

---

### Task 13: AnimatedListItem — 列表入场动画

**Files:**
- Create: `client/lib/core/widgets/animated_list_item.dart`

- [ ] **Step 1: 创建 animated_list_item.dart**

```dart
// client/lib/core/widgets/animated_list_item.dart
import 'package:flutter/material.dart';

/// 列表项入场动画包装器。
///
/// 首次 build 时从下方 20px 淡入滑上。后续 rebuild 不再触发动画。
/// 通过 [index] 实现错位延迟（i * 50ms）。
class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 350),
  });

  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1), // 约 20px
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // 错位延迟，最多 8 个（避免太长列表延迟过久）
    final cappedIndex = widget.index.clamp(0, 8);
    Future.delayed(widget.delay * cappedIndex, () {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _ctrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/animated_list_item.dart
git commit -m "feat(widgets): add AnimatedListItem staggered entrance"
```

---

### Task 14: CelebrationOverlay — 庆祝动画

**Files:**
- Create: `client/lib/core/widgets/celebration_overlay.dart`

- [ ] **Step 1: 创建 celebration_overlay.dart**

```dart
// client/lib/core/widgets/celebration_overlay.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dazi_colors.dart';
import '../theme/glass_theme.dart';

/// 庆祝动画工具。通过静态方法在 Overlay 上展示，避免重建主 widget 树。
class CelebrationOverlay {
  CelebrationOverlay._();

  /// 显示"加入成功"庆祝：✓ 弹出 + 脉冲光环 + 文字。
  static Future<void> showJoinSuccess(BuildContext context, {String? title}) async {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => _JoinSuccessAnimation(title: title));
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1800));
    entry.remove();
  }

  /// 显示"签到成功"庆祝：脉冲波纹 + ✓。
  static Future<void> showCheckinSuccess(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => const _CheckinSuccessAnimation());
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1500));
    entry.remove();
  }
}

class _JoinSuccessAnimation extends StatefulWidget {
  const _JoinSuccessAnimation({this.title});
  final String? title;

  @override
  State<_JoinSuccessAnimation> createState() => _JoinSuccessAnimationState();
}

class _JoinSuccessAnimationState extends State<_JoinSuccessAnimation> with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  late final Animation<double> _ring = Tween<double>(begin: 0, end: 1.5).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );
  late final Animation<double> _fade = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return IgnorePointer(
          child: Container(
            color: Colors.black.withOpacity(0.3 * _fade.value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 脉冲光环
                      Transform.scale(
                        scale: _ring.value,
                        child: Opacity(
                          opacity: _fade.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DaziColors.heroGradientColors[1].withOpacity(0.4),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ✓ 图标
                      ScaleTransition(
                        scale: _scale,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: DaziColors.heroGradientColors,
                            ),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 36),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _scale,
                    child: Text(
                      widget.title ?? '加入成功！',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckinSuccessAnimation extends StatefulWidget {
  const _CheckinSuccessAnimation();

  @override
  State<_CheckinSuccessAnimation> createState() => _CheckinSuccessAnimationState();
}

class _CheckinSuccessAnimationState extends State<_CheckinSuccessAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pulse = Tween<double>(begin: 0, end: 2.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        );
        final fade = Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0)),
        );
        final check = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

        return IgnorePointer(
          child: Container(
            color: Colors.black.withOpacity(0.2 * fade.value),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 脉冲波纹
                  for (var i = 0; i < 3; i++)
                    Transform.scale(
                      scale: pulse.value - (i * 0.3),
                      child: Opacity(
                        opacity: (fade.value * (1 - i * 0.3)).clamp(0.0, 1.0),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ScaleTransition(
                    scale: check,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/widgets/celebration_overlay.dart
git commit -m "feat(widgets): add CelebrationOverlay for join/checkin success"
```

---

## Phase 3：导航壳 + 标记 deprecated（Task 15-16）

### Task 15: home_shell.dart — Glass 导航栏

**Files:**
- Modify: `client/lib/presentation/features/home/home_shell.dart`

- [ ] **Step 1: 重写 home_shell.dart**

使用 GlassTheme token 替换所有硬编码颜色，底部导航栏使用真 BackdropFilter，添加选中态光条动画，发布按钮改为 heroGradient。

关键改动：
- `BottomAppBar` 背景改为 `ClipRect` + `BackdropFilter(blur:20)` + `rgba(base, 0.85)`
- 选中 Tab 的图标加 `drop-shadow` 发光效果
- 选中 Tab 顶部添加 3px 高 primary 色光条（用 `AnimatedPositioned` 滑动过渡）
- 发布 FAB 改为 `Container` + `heroGradient` + `BoxShadow(primaryGlow)`
- 未选中图标/文字用 `textTertiary`

- [ ] **Step 2: 验证编译 + 视觉检查**

Run: `cd C:\dazi-app\client && flutter analyze --no-fatal-infos`

- [ ] **Step 3: Commit**

```bash
git add client/lib/presentation/features/home/home_shell.dart
git commit -m "feat(shell): Glass Morph bottom nav with blur + glow indicator"
```

---

### Task 16: 标记旧 AppColors 为 @deprecated

**Files:**
- Modify: `client/lib/core/theme/app_colors.dart`

- [ ] **Step 1: 在 AppColors 类上添加 @deprecated 注解**

```dart
@Deprecated('Use DaziColors via GlassTheme.of(context).colors instead. Will be removed after all pages migrated.')
class AppColors {
  // ... 保留现有代码不变，迁移期兼容
```

- [ ] **Step 2: Commit**

```bash
git add client/lib/core/theme/app_colors.dart
git commit -m "chore: deprecate AppColors in favor of DaziColors"
```

---

## Phase 4：页面改造（Task 17-37）

> **每个页面的改造模式一致：**
> 1. 包裹 `GlowBackground` 添加背景光斑
> 2. 替换所有 `AppColors.xxx` 为 `GlassTheme.of(context).colors.xxx`
> 3. 替换 `Card` → `GlassCard`，按钮 → `GlassButton`，输入框 → `GlassInput`
> 4. 添加 `AnimatedListItem` 列表入场动画
> 5. 验证 flutter analyze 通过
>
> **以下列出每个 Task 的文件和特殊改动。通用改动步骤不重复。**

### Task 17: Splash 页

**Files:** `client/lib/presentation/features/splash/splash_screen.dart`
- [ ] 暗色底 `colorBase` + 品牌 logo 居中 + 渐变发光入场动画（scale 0→1 + opacity，800ms）
- [ ] Commit: `feat(splash): Glass Morph splash with logo glow animation`

### Task 18: 登录页

**Files:** `client/lib/presentation/features/auth/login_screen.dart`
- [ ] `GlowBackground` 背景 + `GlassInput` 替换手机号输入 + 国家码选择器改为 `GlassCard(level:2)` bottom sheet + 发送按钮改为 `GlassButton(variant: primary)`
- [ ] Commit: `feat(auth): Glass Morph login screen`

### Task 19: 验证码页

**Files:** `client/lib/presentation/features/auth/phone_verify_screen.dart`
- [ ] `GlassInput` 验证码输入 + 倒计时文字用 `textAccent` 色 + 确认按钮 `GlassButton`
- [ ] Commit: `feat(auth): Glass Morph verify screen`

### Task 20: 引导页 (5 步)

**Files:** `client/lib/presentation/features/onboarding/onboarding_screen.dart` + `widgets/step_*.dart`
- [ ] 每步过渡用 `PageView` + 横向滑动动画 + 进度条改为渐变发光条 + 选择卡片改为 `GlassCard` + 城市选择 `PillTag`
- [ ] Commit: `feat(onboarding): Glass Morph 5-step onboarding`

### Task 21: 首页（信息流）

**Files:** `client/lib/presentation/features/home/home_screen.dart` + `widgets/post_card.dart`
- [ ] `GlowBackground` + 分类筛选改为 `PillTag` 横向滚动 + PostCard 全面升级（发布者行 + `AvatarStack` + `GlassCard(level:1)` + 卡片按压缩放动画）+ 列表项 `AnimatedListItem`
- [ ] 城市切换 bottom sheet 改为 `GlassCard(level:2, useBlur:true)`
- [ ] Commit: `feat(home): Glass Morph home feed with new PostCard`

### Task 22: 滑卡页

**Files:** `client/lib/presentation/features/swipe/swipe_screen.dart`
- [ ] 卡片改为 `GlassCard` + 发光边框 + 左滑红色/右滑绿色方向指示叠加 + 成功加入用 `CelebrationOverlay.showJoinSuccess`
- [ ] Commit: `feat(swipe): Glass Morph swipe cards with celebration`

### Task 23: 发现页

**Files:** `client/lib/presentation/features/discover/discover_screen.dart`
- [ ] `GlowBackground` + 筛选栏改为 `PillTag` + `GlassCard` 时间筛选下拉 + DiscoverCard 改为 `GlassCard` + `AnimatedListItem`
- [ ] Commit: `feat(discover): Glass Morph discover with filters`

### Task 24: 搜索页

**Files:** `client/lib/presentation/features/search/search_screen.dart`
- [ ] 搜索框改为 `GlassInput` + 结果列表 `AnimatedListItem` + `GlassCard` 结果项
- [ ] Commit: `feat(search): Glass Morph search screen`

### Task 25: 帖子详情页

**Files:** `client/lib/presentation/features/post/post_detail_screen.dart`
- [ ] Hero 图片过渡 + 信息面板 `GlassCard(level:1)` + `AvatarStack` 参与者 + 加入按钮 `GlassButton(primary)` + 申请列表 `GlassCard`
- [ ] Commit: `feat(post-detail): Glass Morph with Hero + avatar stack`

### Task 26: 发布帖子页

**Files:** `client/lib/presentation/features/post/create_post_screen.dart`
- [ ] 表单项全改 `GlassInput` + 分类选择 `PillTag` + 日期/时间选择器 glass 样式 + 发布按钮 `GlassButton` + 发布成功 `CelebrationOverlay`
- [ ] Commit: `feat(create-post): Glass Morph post form`

### Task 27: 消息列表页

**Files:** `client/lib/presentation/features/messages/messages_screen.dart`
- [ ] 消息项 `GlassCard(level:1)` + 未读红点加发光阴影 `primaryGlow` + `AnimatedListItem` 入场 + 空状态浮动动画
- [ ] Commit: `feat(messages): Glass Morph message list`

### Task 28: 聊天页

**Files:** `client/lib/presentation/features/messages/chat_screen.dart` + `widgets/chat_input_bar.dart`
- [ ] 他人消息气泡 `glassL1` 背景 + 自己消息粉紫渐变背景 + 系统消息居中 pill + 输入栏 `GlassInput` 样式 + 发送按钮渐变
- [ ] Commit: `feat(chat): Glass Morph chat bubbles`

### Task 29: 签到页

**Files:** `client/lib/presentation/features/checkin/checkin_screen.dart`
- [ ] GPS 定位动画 + 签到成功 `CelebrationOverlay.showCheckinSuccess` + `GlassCard` 信息面板
- [ ] Commit: `feat(checkin): Glass Morph with celebration animation`

### Task 30: 评价页

**Files:** `client/lib/presentation/features/review/review_screen.dart`
- [ ] 评价卡 `GlassCard` + 星星用 `starColor` + 提交按钮 `GlassButton`
- [ ] Commit: `feat(review): Glass Morph review cards`

### Task 31: AI 回忆卡页

**Files:** `client/lib/presentation/features/review/recap_card_screen.dart`
- [ ] `GlowBackground` 增加蓝色光斑 + 卡片 `GlassCard(level:2)` + 文字用打字机效果（逐字显示 AnimatedBuilder）
- [ ] Commit: `feat(recap): Glass Morph AI recap card with typewriter`

### Task 32: 个人主页

**Files:** `client/lib/presentation/features/profile/profile_screen.dart` + `profile_tabs.dart`
- [ ] 头部区域 `GlassCard` + Hero 头像过渡 + Tab 切换动画 + 帖子/评价列表 `GlassCard` + `AnimatedListItem`
- [ ] Commit: `feat(profile): Glass Morph profile with Hero avatar`

### Task 33: 编辑资料页

**Files:** `client/lib/presentation/features/profile/edit_profile_screen.dart`
- [ ] 表单全改 `GlassInput` + 头像上传区 `GlassCard` + 保存 `GlassButton`
- [ ] Commit: `feat(edit-profile): Glass Morph edit form`

### Task 34: 隐私设置页

**Files:** `client/lib/presentation/features/profile/privacy_settings_screen.dart`
- [ ] 开关项改为 `GlassCard(level:1)` + Switch 的 activeColor 用 `primary`
- [ ] Commit: `feat(privacy): Glass Morph settings`

### Task 35: 通知设置页

**Files:** `client/lib/presentation/features/profile/notifications_settings_screen.dart`
- [ ] 同 Task 34 模式
- [ ] Commit: `feat(notifications): Glass Morph settings`

### Task 36: 黑名单页

**Files:** `client/lib/presentation/features/profile/blocked_users_screen.dart`
- [ ] 列表项 `GlassCard` + 解除拉黑 `GlassButton(danger)`
- [ ] Commit: `feat(blocked): Glass Morph list`

### Task 37: 紧急联系人页

**Files:** `client/lib/presentation/features/profile/emergency_contacts_screen.dart`
- [ ] 列表项 `GlassCard` + 添加按钮 `GlassButton(secondary)`
- [ ] Commit: `feat(emergency): Glass Morph contacts`

---

## Phase 5：收尾（Task 38-40）

### Task 38: 清理 @deprecated AppColors 引用

**Files:** 全局搜索 `AppColors.`

- [ ] `grep -r "AppColors\." client/lib/` 找到所有残留引用
- [ ] 逐一替换为 `GlassTheme.of(context).colors.xxx`
- [ ] 确认 `flutter analyze` 零 deprecation warning
- [ ] Commit: `refactor: remove all AppColors references`

### Task 39: CI 验证

- [ ] Run: `cd C:\dazi-app && python scripts/run_ci.py`
- [ ] 修复任何失败
- [ ] Commit fixes if needed

### Task 40: 更新文档

**Files:** `.plans/dazi-app/task_plan.md`, `CLAUDE.md`

- [ ] 在 `task_plan.md` 记录 Glass Morph 升级完成
- [ ] 在 `CLAUDE.md` 的风格决策中添加 SD-5：Glass Morph 主题系统规则
- [ ] Commit: `docs: update plan and CLAUDE.md for Glass Morph completion`
