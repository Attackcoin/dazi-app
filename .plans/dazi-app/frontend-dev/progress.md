# frontend-dev - 工作日志

> 用于上下文恢复。压缩/重启后先读此文件。

---

## 2026-04-16: T5-02 + T5-07 完成

**任务**: T5-02 PostCard 押金保障标签 + T5-07 演出分类
**状态**: 完成，flutter analyze 零错误

**改动**:
- `post_card.dart`: 分类 PillTag 旁加绿色"押金保障" PillTag（depositAmount > 0 时显示）
- `post_detail_screen.dart`: info box 下新增 _buildDepositBanner（盾牌图标 + 金额 + 说明）
- `category_repository.dart`: _defaults 新增"演出"分类（演唱会/音乐节/展览/体育赛事）
- `seed_posts.js`: 新增 4 条演出帖（含 depositAmount 示例）

**备注**: eventName/eventDate 字段未加入 Post 模型，需先同步 firestore.rules hasOnly 白名单（KP-7），记录为 backlog

---

## 2026-04-12: T1 UI 修复完成

**任务**: 修复 reviewer [BLOCK] 报告中的 HIGH + MEDIUM 前端问题
**状态**: 全部完成，flutter analyze 零错误

**修复列表**:
- H-1: withdrawApplication → Cloud Function（需 backend-dev 配合）
- H-9: scannedUid 传递给签到后端验证
- H-10: post_detail error 分支加 Scaffold + AppBar + 重试
- M-1: 移除无效的距离筛选 UI
- M-2: 6 个 screen error 分支补重试按钮
- M-3/M-4: 硬编码颜色 → AppColors（新增 starColor/successGreen）
- M-5: ChatMessage 加 senderName 冗余字段，消除 N+1

**待协调**: backend-dev 需实现 `withdrawApplication` Cloud Function
