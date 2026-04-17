# T5-06 Progress

## 2026-04-17
- 开始实施：读取现有 firestore.rules、index.js、测试 setup.js 了解模式
- Step 1: firestore.rules — posts create 白名单添加 seriesId/recurrence/seriesWeek/seriesTotalWeeks（不加到 update 白名单）
- Step 2: 创建 functions/src/series.js — createSeriesPosts onCall Cloud Function
- Step 3: firestore.indexes.json — 添加 posts seriesId ASC + seriesWeek ASC 复合索引
- Step 4: index.js — 导出 series 模块
- Step 5: 创建 functions/__tests__/series.test.js — 11 个测试用例全部通过
- Step 6: 更新 api-contracts.md — 新增 createSeriesPosts 端点文档 + posts 集合字段说明
- 全量测试：58/58 通过，0 失败
- **状态：完成**
