# frontend-dev - 发现记录

> 工作中发现的问题和技术要点。

---

## 任务索引

| 任务 | 文件夹 | 状态 |
|------|--------|------|
| T1: UI 修复 (HIGH + MEDIUM) | `task-ui-fixes/` | 完成，flutter analyze 零错误 |

---

## 关键发现

### H-1: withdrawApplication 需后端 Cloud Function
`firestore.rules:28-30` 只允许帖子发布者 update applications，申请者无权直写 status。
前端已改为调用 `withdrawApplication` Cloud Function，需 backend-dev 实现对应函数。

### M-5: ChatMessage 新增 senderName 冗余字段
为彻底消除 N+1，在 `chat_message.dart` 添加了 `senderName` 字段（读写 RTDB 同步）。
`sendText/sendImage` 调用时已传 `senderName`，历史消息 fallback 到 UID 前 6 字符。

### AppColors 新增颜色
- `starColor = Color(0xFFFFC107)` — 统一星评颜色
- `successGreen = Color(0xFF4CAF50)` — 签到成功状态绿色
