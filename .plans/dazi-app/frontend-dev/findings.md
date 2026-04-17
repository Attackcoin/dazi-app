# frontend-dev - 发现记录

> 工作中发现的问题和技术要点。

---

## 任务索引

| 任务 | 文件夹 | 状态 |
|------|--------|------|
| T1: UI 修复 (HIGH + MEDIUM) | `task-ui-fixes/` | 完成，flutter analyze 零错误 |
| Fix HIGH SD-5 + split profile_screen | `task-fix-high-sd5-and-split-profile/` | 完成，CI 46/46 PASS (2026-04-13) |
| T1: Repository 单测补齐 + ErrorRetryView 组件化 | `task-t1-tests-and-retry/` | 进行中 (2026-04-13) |
| T5-02+T5-07: 押金保障标签 + 演出分类 | `task-deposit-tag-and-concert-category/` | 完成 (2026-04-16) |
| T5-01: 身份验证 UI（徽章+入口） | `task-identity-verification-ui/` | 完成 (2026-04-17) |
| T5-04: 地理搜索增强（Algolia GeoSearch） | `task-geo-search/` | 完成 (2026-04-17) |

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
