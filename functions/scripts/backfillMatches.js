#!/usr/bin/env node
/**
 * 一次性脚本：给历史 match 文档补齐 denormalized 字段。
 *
 * 适用场景：在 `acceptApplication` 升级为写入 postTitle /
 * postCategory / participantInfo / lastMessageAt / lastMessagePreview
 * 之前创建的 match 文档，MessagesScreen / ChatScreen 会因缺字段显示为
 * 空串。此脚本用当前 post + user 的数据回填。
 *
 * ─── 使用方法 ─────────────────────────────────────────────
 *
 * 1. 从 Firebase Console 下载 service account JSON：
 *    项目设置 → 服务帐号 → 生成新的私钥
 *
 * 2. 设置环境变量指向该文件：
 *      Windows (PowerShell):
 *        $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\sa.json"
 *      bash:
 *        export GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json
 *
 * 3. 先 dry-run 预览（不写入）：
 *      node functions/scripts/backfillMatches.js
 *
 * 4. 确认无误后加 --apply 真正写入：
 *      node functions/scripts/backfillMatches.js --apply
 *
 * ─── 行为说明 ─────────────────────────────────────────────
 *
 * - 仅处理缺 `postTitle` 或 `participantInfo` 的 match。
 * - 若 post 已被删除，跳过该 match 并在日志中标记。
 * - 若某位 participant 的 user doc 不存在，该参与者的 info 填空串但继续处理。
 * - 不覆盖已有字段：用 set({ merge: true }) 合并。
 * - 按 200 条一批处理，避免单次读写过多。
 */

const admin = require('firebase-admin');

const APPLY = process.argv.includes('--apply');
const BATCH_SIZE = 200;

admin.initializeApp();
const db = admin.firestore();

async function main() {
  console.log(`[backfillMatches] mode = ${APPLY ? 'APPLY' : 'DRY-RUN'}`);
  console.log('[backfillMatches] fetching all matches...');

  const snap = await db.collection('matches').get();
  console.log(`[backfillMatches] total matches: ${snap.size}`);

  const needFix = snap.docs.filter((d) => {
    const data = d.data();
    return !data.postTitle || !data.participantInfo;
  });
  console.log(`[backfillMatches] need backfill: ${needFix.length}`);

  if (needFix.length === 0) {
    console.log('[backfillMatches] nothing to do, exiting.');
    return;
  }

  // 预取所有涉及的 post + user doc，减少重复读取
  const postIds = new Set();
  const uids = new Set();
  for (const m of needFix) {
    const data = m.data();
    if (data.postId) postIds.add(data.postId);
    (data.participants || []).forEach((u) => uids.add(u));
  }
  console.log(
    `[backfillMatches] fetching ${postIds.size} posts + ${uids.size} users...`
  );

  const [postSnaps, userSnaps] = await Promise.all([
    Promise.all(
      Array.from(postIds).map((id) => db.collection('posts').doc(id).get())
    ),
    Promise.all(
      Array.from(uids).map((id) => db.collection('users').doc(id).get())
    ),
  ]);

  const postMap = new Map(postSnaps.map((s) => [s.id, s.exists ? s.data() : null]));
  const userMap = new Map(userSnaps.map((s) => [s.id, s.exists ? s.data() : null]));

  let fixed = 0;
  let skipped = 0;
  let batch = db.batch();
  let inBatch = 0;

  for (const m of needFix) {
    const data = m.data();
    const post = postMap.get(data.postId);
    if (!post) {
      console.warn(
        `  [skip] match ${m.id} — post ${data.postId} not found`
      );
      skipped++;
      continue;
    }

    const participantInfo = {};
    for (const uid of data.participants || []) {
      const u = userMap.get(uid) || {};
      participantInfo[uid] = {
        uid,
        name: u.name || '',
        avatar: u.avatar || '',
      };
    }

    const patch = {
      postTitle: post.title || '',
      postCategory: post.category || '',
      participantInfo,
    };
    // 仅当字段原先缺失时才补 lastMessageAt / lastMessagePreview
    if (data.lastMessageAt == null) {
      patch.lastMessageAt =
        data.createdAt || admin.firestore.FieldValue.serverTimestamp();
    }
    if (data.lastMessagePreview == null) {
      patch.lastMessagePreview = '';
    }

    console.log(
      `  [fix] match ${m.id} — "${patch.postTitle}" (${data.participants.length} participants)`
    );

    if (APPLY) {
      batch.set(m.ref, patch, { merge: true });
      inBatch++;
      if (inBatch >= BATCH_SIZE) {
        await batch.commit();
        console.log(`  [commit] ${inBatch} writes flushed`);
        batch = db.batch();
        inBatch = 0;
      }
    }
    fixed++;
  }

  if (APPLY && inBatch > 0) {
    await batch.commit();
    console.log(`  [commit] ${inBatch} writes flushed (final)`);
  }

  console.log('[backfillMatches] ─── summary ───');
  console.log(`  total matches:  ${snap.size}`);
  console.log(`  fixed:          ${fixed}${APPLY ? '' : ' (dry-run)'}`);
  console.log(`  skipped:        ${skipped}`);
  console.log(`  mode:           ${APPLY ? 'APPLY' : 'DRY-RUN'}`);
  if (!APPLY) {
    console.log('\n  add --apply to actually write changes.');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('[backfillMatches] fatal:', err);
    process.exit(1);
  });
