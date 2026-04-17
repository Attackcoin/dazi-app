# T5-06 系列活动 UI

## 范围
- Post model 新增 seriesId/recurrence/seriesWeek/seriesTotalWeeks 字段
- CreatePostScreen 添加系列活动创建入口（Switch + 频率选择 + 总周数）
- PostCard 系列标识 PillTag
- PostDetailScreen 系列信息区域 + 可展开的其他期次列表
- PostCreateRepository.createSeries() 调用 Cloud Function
- PostRepository.watchSeriesPosts() + seriesPostsProvider
- i18n: 9 个新 arb key（中英文）

## 验收标准
1. `flutter analyze` 零错误
2. `flutter gen-l10n` 无报错
3. Post model 正确解析系列字段
4. CreatePostScreen 有系列活动创建入口
5. PostCard 和 PostDetailScreen 显示系列标识
6. 所有新文案已加入 arb 文件

## 状态
- [x] Phase A: Post model 更新
- [x] Phase B: CreatePostScreen + PostCreateRepository
- [x] Phase C: PostCard + PostDetailScreen
- [x] Phase D: i18n
- [x] flutter analyze: PASS (0 errors, 0 warnings, 4 pre-existing info)
- [x] flutter gen-l10n: PASS
