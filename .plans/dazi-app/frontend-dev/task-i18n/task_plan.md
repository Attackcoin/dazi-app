# T5-05 i18n 国际化基础

## 目标
为 dazi-app Flutter 客户端接入国际化（中文简体 + 英文），实现系统语言自动切换 + 手动切换入口。

## Phase A: 基础设施搭建
- [x] pubspec.yaml 添加 flutter_localizations + intl + generate: true
- [x] 创建 client/l10n.yaml
- [x] 创建 app_zh.arb + app_en.arb
- [x] MaterialApp.router 配置 localizationsDelegates + supportedLocales
- [x] flutter gen-l10n 无报错

## Phase B: 核心页面文案抽取
- [x] home_shell.dart (tab 标签)
- [x] login_screen.dart
- [x] set_password_screen.dart
- [x] onboarding_screen.dart + step widgets
- [x] create_post_screen.dart + create_post_quota.dart
- [x] post_detail_screen.dart + apply_sheet + application_list_sheet
- [x] profile_screen.dart + parts
- [x] post_card.dart
- [x] discover_screen.dart
- [x] swipe_screen.dart
- [x] chat_screen.dart + messages_screen.dart
- [x] search_screen.dart
- [x] review_screen.dart + recap_card_screen.dart

## Phase C: 语言切换入口
- [x] locale Provider (Riverpod Provider 模式)
- [x] MaterialApp locale 绑定
- [x] profile 设置区添加语言切换入口

## 验收
- [ ] flutter gen-l10n 无报错
- [ ] flutter analyze 零错误
- [ ] 英文模式无中文硬编码
- [ ] 中文模式功能正常
- [ ] 默认跟随系统语言
