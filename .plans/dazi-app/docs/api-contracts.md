# dazi-app - API 契约

> Dev 变更 API 时必须同步更新此文件。

## Firebase Functions 端点 (asia-southeast1)

| 方法 | 端点 | 描述 | 请求 | 响应 |
|------|------|------|------|------|
| (待 researcher 盘点后填充) | | | | |

## Firestore Collections

| Collection | 用途 | 关键字段 |
|-----------|------|---------|
| users | 用户信息 | name, avatar, city, tags, rating |
| posts | 帖子/局 | title, category, time, location, totalSlots, status |
| applications | 申请记录 | postId, applicantId, status |
| matches | 匹配记录 | postId, participants |
| reviews | 评价 | fromUid, toUid, postId, rating, tags |
| categories | 分类配置 | id, label, emoji |

## Realtime Database

| 路径 | 用途 |
|------|------|
| chats/{postId}/messages/{msgId} | 群聊消息 |
