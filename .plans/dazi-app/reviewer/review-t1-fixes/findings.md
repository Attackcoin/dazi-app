# T1 修复审查 — 逐条发现

**审查员**: reviewer | **日期**: 2026-04-14 | **范围**: T1 安全/并发修复（H-1~H-7 + M-1/M-3/M-5/M-9）

---

## H-1: applyToPost 确定性 docId + CAS

**结论: VERIFIED**

- `applications.js:36` 确认 `appRef = db.collection('applications').doc(`${postId}_${uid}`)` 在事务外构造、事务内 `tx.get`（L37）。
- 幂等检查 `['pending', 'accepted', 'waitlisted'].includes(existingAppDoc.data().status)`（L39）涵盖三个有效状态，包括 waitlisted 路径。
- `FieldValue.increment` 用于 `acceptedGender.male/female`（L152），在 tx 内。
- tx.get 在 tx.update/tx.set 之前——正确顺序。
- 测试 `applications.test.js:65-96`：首次/重复（already-exists）双向断言，PASS。
- **微观隐患**（非阻塞）：`status == 'withdrawn'` 或 `status == 'expired'` 的历史申请被允许再次申请（existingAppDoc.exists 为 true 但 status 不在上述三项，跳过 throw）。这是合理的业务设计（被拒/过期/撤回可重申），但需确认 ADR 有记录。查 architecture.md 未见明确说明，建议补注释或加 ADR 条目。

---

## H-2: submitReview toUserId 校验

**结论: VERIFIED**

- `applications.js:305`: `if (!match.participants.includes(toUserId) || toUserId === fromUid)` — 两条校验均在，单行复合表达式。
- 测试 `applications.test.js:218-237`：外部用户 stranger + 自评两个负向用例，PASS。

---

## H-3: submitReview 事务化

**结论: VERIFIED**

- `applications.js:318-338`：`db.runTransaction` 内先 `tx.get(reviewRef)` 检查重复（L319），再 `tx.set`（L323）+ `tx.update` 用户 ratingSum/ratingCount（L334-337）——三步同事务。
- 幂等：`existingReview.exists` 抛 `already-exists`（L321）。
- 测试：正常评价（ratingSum/ratingCount 验证）+ 重复评价（already-exists）两向，PASS。

---

## H-4: submitCheckin runTransaction + CAS

**结论: VERIFIED**

- `antiGhosting.js:80-148`：整个业务逻辑在 `db.runTransaction` 闭包内。
- 最后一人 CAS（L128）：`match.participants.every((p) => newCheckedIn.includes(p))`，在事务内基于事务快照判定，无竞态。
- `totalMeetups` increment 仅在 `allDone` 分支下对所有 participants 做一次（L139-142），不会双计数。
- `_onAllCheckedIn` 已被删除，移除了原 batch 路径（diff 确认），副作用移至事务外（L151-164）。
- 测试：单人签到（allCheckedIn=false，totalMeetups 不变）+ 最后一人（completed + totalMeetups++）两向，PASS。

---

## H-5: ghostCount restricted 下沉

**结论: VERIFIED**

- `antiGhosting.js:210-213`：`batch.update(userRef, { ghostCount: admin.firestore.FieldValue.increment(1) })` — 原 read-modify-write 已去除（diff 确认删除 `userDoc.get()` + `newCount` 计算）。
- `isRestricted` 字段不再由 onCheckinTimeout 更新（已删除），改为在 `applications.js:47` 实时判定 `(user.ghostCount || 0) >= 3`——覆盖 pending 和 waitlisted 路径（因为这是 applyToPost 入口，所有新申请都走这里）。
- 测试：`ghostCount>=3` 用例（applications.test.js:98-107），PASS。
- **注意**：已有 `ghostCount==2` 的用户在 onCheckinTimeout 中再次 ghosted，increment 变为 3，但在下次 applyToPost 之前不会被"限制"——这属于已知设计选择（入口实时判定），合理，ADR 注释已在代码里。

---

## H-6: AI 鉴权

**结论: VERIFIED**

- `ai.js:133-136`：`generateIcebreakers` onCall 层检查 `Array.isArray(match.participants) && match.participants.includes(context.auth.uid)`。
- `ai.js:199-203`：`generateRecapCard` onCall 层同样检查。
- 内部 `_generateRecapCard`（L209）不加校验——正确，由 `antiGhosting` 可信路径触发。
- **覆盖缺口**（非阻塞）：dev 的 findings 写"鉴权覆盖通过 applications/antiGhosting 间接测"，但实际上 ai.js 没有单独的 Jest 测试文件。两个 onCall 函数的鉴权路径没有正向/负向单测。这不是阻塞项（功能已实现），但 RD-4 扣分点：H-6 相关的鉴权断言缺失，属于测试不完整。

---

## H-7: deposits 幂等 + CAS

**结论: VERIFIED**

- `deposits.js:73`：`depositId = `${matchId}_${uid}``，确定性。
- `deposits.js:76-149`：整个 freezeDeposit 逻辑在 `db.runTransaction` 内，读-判状态-写三步原子。
- 状态分支（L93-112）：`frozen`/`sesame_guaranteed` → alreadyFrozen；`pending_payment` → 复用 orderId resumed；`refunded`/`ghost_deducted` → failed-precondition。覆盖所有终结状态。
- `depositPaymentCallback`（L184-197）：`db.runTransaction` 内 CAS `status==pending_payment` 才升 `frozen`（L189-196）；`status==frozen` no-op（L188）；其他状态 warn（L190-192）。
- 测试（deposits.test.js）：8 用例覆盖全路径，PASS。

---

## M-1: GPS 强制

**结论: VERIFIED**

- `antiGhosting.js:110-123`：`typeof postLat === 'number' && typeof postLng === 'number'` 判断 post 是否有坐标，有坐标时检查客户端是否上报（L111-115：invalid-argument），再校验距离（L116-122：out-of-range）。
- 测试：3 个 GPS 测试用例（未传 / 过远 / 在范围），PASS。
- **完整性检查**：`post.location && post.location.lat` 取值（L106-107）在 `post.location` 为空对象 `{}` 时 postLat = undefined，`typeof undefined === 'number'` 为 false，故不会误报 GPS 要求——正确。

---

## M-3: firestore.rules applications create

**结论: VERIFIED**

- `firestore.rules:77-79`：`applicantId == request.auth.uid && status == 'pending'` 两条约束均在。
- diff 确认从原来 `allow create: if request.auth != null` 扩充了两条字段断言。
- **注意**：rules 未加 `applicationId == `${postId}_${uid}`` 的 docId 格式校验（Firestore rules 做不到），但这是已知限制，Functions 层已有确定性 docId 保障，不构成漏洞。

---

## M-5: 月份 label + 分批

**结论: VERIFIED**

- `ai.js:295`：`monthStart.getMonth() + 1`，用 `monthStart`（上月1日）而非 `now`（本月1日），修正偏移。
- `ai.js:299-329`：`BATCH=10` + `Promise.all(batch.map(generateOne))` 分批并发，each catch 独立，不会因一个用户失败中断全批。
- **未单测**：dev findings 已说明"依赖真实 Anthropic client"，符合实际（这个 scheduled function 测试成本高），接受。

---

## M-9: acceptApplication 满员清理

**结论: VERIFIED (with documented race window)**

- `applications.js:105-120`：事务外 pre-fetch `otherPendingRefs`（L114-120）。
- `applications.js:159-163`：事务内满员时 `for...tx.update(ref, { status: 'auto_rejected' })`。
- Race 窗口：pre-fetch 与事务之间新进来的 pending 申请不在 otherPendingRefs 中，会遗留 pending 状态，由 24h `expireApplications` 兜底。
- 代码注释（L105-108）明确记录了这个权衡，ADR 文字已在代码内联。architecture.md 无专门段落，但 api-contracts.md 已描述 auto_rejected 语义。
- **M-9 ADR 记录确认**：代码注释有，但 decisions.md 未单独有条目。这是轻微文档遗漏，不阻塞。
- 测试：满员清理 + 非发布者两向，PASS。

---

## Jest 测试质量

**结论: ADEQUATE — 功能正确，但事务模拟有语义简化**

### FakeTransaction 语义分析

`setup.js:290-295`：`runTransaction(fn)` 实现：
```js
async runTransaction(fn) {
  const tx = new FakeTransaction(this);
  const result = await fn(tx);  // fn 执行期间 writes[] 累积
  tx._flush();                    // 执行完毕后批量写入
  return result;
}
```

`FakeTransaction.get(ref)` 直接读 `store.docs`（L251-257），即读的是已提交的状态，**不是事务快照**。这意味着：

1. **同一事务内多次 tx.get 同一文档**：第一次读完、第二次在 `_flush` 前读，仍然读到提交前的状态——在单线程 fake 中是正确的。
2. **两个并发事务竞争**：测试没有并发场景（没有两个 `Promise.all([runTransaction, runTransaction])`），所有测试都是串行单 tx。因此 `_flush` 延迟提交的语义对测试是正确的，但**不验证真实 Firestore 事务的 snapshot isolation 和重试语义**。

这是 mock 层已知简化，在团队文档（`setup.js:3-8`）已有说明。对于"验证业务逻辑是否正确调用了 runTransaction"这个目标，现有 fake 是足够的。

### FieldValue sentinel 解引用

`setup.js:33-52`：sentinel 在 `mergeUpdate`（L54-75）和 `FakeBatch.commit`（L233-243）里正确解引用。`FieldValue.increment` 在事务读-写路径中通过 `mergeUpdate` 正确叠加。`_flush` 时调用 `mergeUpdate`，increment 语义正确。

### mock 边界

两个 jest.mock 目标是 `firebase-admin`（外部边界）和 `firebase-functions`（外部边界），不 mock 自己模块。antiGhosting.test.js 另 mock `../src/ai` 和 `../src/notifications`（跨模块边界，合理）。

### 覆盖缺口

| 缺失 | 严重度 |
|------|--------|
| ai.js generateIcebreakers/generateRecapCard 鉴权 | LOW（功能已实现，仅无单测）|
| depositPaymentCallback HTTP handler 测试 | LOW（无法方便地 mock req/res，可接受）|
| 并发 race condition 测试（两个 tx 同时写）| MEDIUM（fake 架构本身不支持，需 emulator 才能测）|

---

## 前端 ErrorRetryView

**结论: VERIFIED**

- `error_retry_view.dart`：颜色全走 `GlassTheme.of(context).colors.*`（L31, 38, 41），间距走 `Spacing.*`（L33, 39, 44），无硬编码 `Color(0xFF...)`。符合 SD-5。
- `withOpacity` 未使用（组件内无透明度调用），符合 SD-5 禁用规则。
- `error` 字面量：`debugPrint` 只在 kDebugMode 下输出（`debugPrint` Flutter 内置），不向用户暴露。
- sliver 分支（L54-59）：`SliverFillRemaining` 正确实现。
- 7 处替换点：grep 验证 8 个文件（含组件本身）全部 import `error_retry_view.dart`，7 个使用点均已替换。
- Widget 测试：4 用例（渲染/默认消息/onRetry/sliver），PASS。`GlassTheme` 包在 `MaterialApp` 外层（测试文件 L7-11），符合 SD-5 要求。

---

## Doc-Code Sync

**结论: ADEQUATE**

- `api-contracts.md`：已为 applyToPost（applicationId 语义、幂等）、acceptApplication（auto_rejected）、submitReview（H-2/H-3）、submitCheckin（GPS 强制、H-4）、freezeDeposit（depositId 语义、状态分支）、depositPaymentCallback（CAS）、generateIcebreakers/RecapCard（H-6）、generateMonthlyReports（M-5）添加契约条目。内容与代码一致。
- `architecture.md`：新增"安全与并发"章节，覆盖全部 T1 修复要点。
- **轻微遗漏**：`api-contracts.md` 的 Firestore Collections 表中 reviews 的 `fromUid/toUid` 字段名与代码中的 `fromUser/toUser` 不一致（表内写 `fromUid/toUid`，代码是 `fromUser/toUser`）。不阻塞，建议 T2 修正。

---

## 前端 Repository 改动（application_repository.dart + match_repository.dart）

**结论: BONUS — 额外的正向改动**

两个 repository 增加了 `limit` 参数（默认 50），限制 watchApplicationsForPost 和 watchMyMatches 的 Snapshot 监听返回量，有助于 RD-3（Firebase 成本）。改动简洁安全，无风险。

