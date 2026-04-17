# T5-02 + T5-07: 押金保障标签 + 演出分类

## T5-02: PostCard 展示押金保障标签 (P0)

### 范围
- `post_card.dart` — `depositAmount > 0` 时，在分类 PillTag 旁加"押金保障" PillTag (success 色)
- `post_detail_screen.dart` — 有押金时，info box 下方展示押金 banner（盾牌图标 + 金额 + 说明）
- semantics label 包含押金信息

### 验收
- [x] PostCard 有押金时显示绿色"押金保障"标签
- [x] PostDetailScreen 展示押金金额和说明
- [x] flutter analyze 零 error
- [x] 视觉风格 Glass Morph 一致（颜色走 gt.colors.success, 透明度用 withValues）

## T5-07: 演唱会搭子分类 (P1)

### 范围
- `category_repository.dart` — _defaults 加"演出"分类，子标签：演唱会/音乐节/展览/体育赛事
- `seed_posts.js` — 新增 4 条演出类测试帖子（含押金示例）

### 验收
- [x] 用户发帖时可选"演出"分类及子分类
- [x] flutter analyze 零 error

## 状态: 完成
