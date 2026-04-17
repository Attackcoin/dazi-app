# T5-06: 重复活动组（系列活动）— 后端

## 范围
实现系列活动的后端支持：firestore.rules 白名单、createSeriesPosts onCall Function、复合索引、测试。

## 验收标准
1. `npm test` 全部通过
2. firestore.rules posts create 白名单已添加 seriesId/recurrence/seriesWeek/seriesTotalWeeks
3. firestore.indexes.json 已添加 seriesId + seriesWeek 复合索引
4. api-contracts.md 已更新
5. series.js + series.test.js 完整

## 实现步骤
- [x] Step 1: 更新 firestore.rules — posts create 白名单加 4 个字段
- [x] Step 2: 创建 functions/src/series.js — createSeriesPosts onCall
- [x] Step 3: 更新 firestore.indexes.json — seriesId + seriesWeek 复合索引
- [x] Step 4: 在 index.js 导出 series 模块
- [x] Step 5: 创建 functions/__tests__/series.test.js
- [x] Step 6: 更新 api-contracts.md

## 依赖
无外部依赖，纯后端任务。
