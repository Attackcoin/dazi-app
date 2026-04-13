# audit-post-fix - 任务计划

## 目标
大修复轮次（2 CRITICAL + 10 HIGH + 8 MEDIUM）完成后的合规巡检与代码清理。

## 范围
1. Doc-Code Sync 检查
2. 死代码扫描
3. 文件大小检查（>800 行标记）
4. Known Pitfalls 更新建议
5. 风格一致性检查（SD-1~SD-4 + AppColors）

## 验收标准
- findings.md 完成，每条问题分级 [CRITICAL] / [ADVISORY]
- 根 findings.md 添加索引条目
- 发消息给 team-lead

## 状态
- [x] 巡检执行完毕（2026-04-12）
- [x] findings.md 已写入
