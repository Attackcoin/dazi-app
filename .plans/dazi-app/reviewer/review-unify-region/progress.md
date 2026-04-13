# review-unify-region Progress

## 2026-04-09 审查执行

### Step 1 — 上下文收集
- 读取 `.plans/dazi-app/backend-dev/task-unify-region/findings.md` 了解 dev 自述
- 确认修改范围：functions/src 21 处 + client 1 运行时 + 2 注释 = 24 处

### Step 2 — 独立 grep 验证（并行执行）
- `asia-east1` in functions/src → 0 匹配 [OK]
- `asia-east1` in client/lib → 0 匹配 [OK]
- `.region(` in functions → 21 处全部 asia-southeast1 [OK]
- `FirebaseFunctions.instanceFor` in client → 1 处，常量已改 [OK]
- `'asia-|"asia-` 全仓 → 源代码侧只剩 asia-southeast1 [OK]
- `us-central1|europe-|asia-northeast` 全仓 → 0 匹配 [OK]

### Step 3 — 关键发现独立验证
- Grep `firebaseFunctionsProvider` in client/lib/data/repositories
- 确认 checkin_repository.dart:4,7 和 review_repository.dart:4,7 确实 import application_repository 并共享 provider
- dev 的"单点修复三处"策略**属实**

### Step 4 — 遗漏点扫描
- functions/index.js：Firebase 脚手架残留，package.json main 指向 src/index.js，无影响
- functions/src/index.js：纯重导出，无 region 配置
- functions/src/env.example：只含 `ALIYUN_REGION=cn-hangzhou`（阿里云实人认证，无关）
- firebase.json：Firestore location 正确，functions 字段无 region 属性
- **无代码侧遗漏**

### Step 5 — 运行时风险评估
- 核对 dev 的 6 条部署警告，全部准确
- 独立提高 Firestore 触发器双跑风险评级为 CRITICAL（押金相关触发器双跑可能资金错账）
- 将 dev 的"5 分钟窗口"收紧为"< 2 分钟"
- 整理出可执行的部署 Checklist（T-0 / T+0 / T+2min / T+10min / 支付启用前）

### Step 6 — 报告落盘
- 写 findings.md（判定 [OK]）
- 写 progress.md（本文件）
- 更新 reviewer 根 findings.md 索引
