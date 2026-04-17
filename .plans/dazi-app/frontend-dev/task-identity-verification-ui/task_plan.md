# T5-01 身份验证系统 — 前端 UI

## 目标
在 ProfileScreen / PostDetailScreen / DiscoverScreen 展示验证徽章 + 验证入口。

## 验收标准
1. `flutter analyze` 零错误
2. `flutter gen-l10n` 无报错
3. ProfileScreen：level >= 2 显示蓝色验证徽章；level < 2 且 isSelf 显示"验证身份"入口
4. PostDetailScreen：_PublisherRow 显示验证徽章（level >= 2）
5. DiscoverScreen：筛选栏添加"已验证"PillTag（UI 就绪，数据筛选待 Post model 增加字段）
6. 所有新文案已加入 zh/en arb 文件

## 范围
- Phase A: 验证徽章展示（ProfileScreen header + PostDetailScreen publisher row）
- Phase B: 验证流程入口（ProfileScreen BottomSheet placeholder + DiscoverScreen filter chip）
- Phase C: i18n 文案

## 不做
- 不安装 stripe_identity
- 不改后端 / rules / AppUser model
- PostCard 不加徽章（Post model 无 publisherVerificationLevel 字段）
