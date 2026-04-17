# T5-12 安全伴侣 — 进度

## 2026-04-17
- [x] 读取现有代码结构（antiGhosting.js, notifications.js, setup.js）
- [x] 新建 safety.js：confirmSafety + escalateSafetyAlert + _createSafetyAlert
- [x] 修改 antiGhosting.js：onCheckinTimeout 调用 _createSafetyAlert
- [x] 更新 firestore.rules：safetyAlerts 集合规则
- [x] 更新 src/index.js：导出 safety 模块
- [x] 编写 safety.test.js：14 个测试（confirmSafety 5 + escalate 4 + _create 5）
- [x] 修复 setup.js Timestamp mock 的 valueOf() 使 FakeQuery <= 比较正确
- [x] npm test 全部通过：72/72
- [x] 更新 api-contracts.md
- [x] 创建任务文件夹

## 遇到的问题
- Strike 1：Timestamp mock 对象无 valueOf()，FakeQuery 的 <= 比较对所有 Timestamp 都返回 true。修复：添加 valueOf() 返回秒数。
