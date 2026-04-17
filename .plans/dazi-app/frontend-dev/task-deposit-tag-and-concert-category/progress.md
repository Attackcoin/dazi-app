# T5-02 + T5-07 Progress

## 2026-04-16: 完成

### T5-02 押金保障标签
- post_card.dart: 在分类 PillTag 旁加绿色"押金保障" PillTag（Wrap 布局）
- post_detail_screen.dart: info box 下方新增 _buildDepositBanner（盾牌图标 + 金额 + 说明文字）
- semantics label 加入"押金保障"
- flutter analyze: 零 error

### T5-07 演出分类
- category_repository.dart: _defaults 新增"演出"分类（sort=5），游戏改为 sort=6
- seed_posts.js: 新增 4 条演出类帖子（含 depositAmount 字段）

### 改动文件
- `client/lib/presentation/features/home/widgets/post_card.dart`
- `client/lib/presentation/features/post/post_detail_screen.dart`
- `client/lib/data/repositories/category_repository.dart`
- `scripts/seed_posts.js`
