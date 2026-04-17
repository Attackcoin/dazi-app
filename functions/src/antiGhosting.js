/**
 * 防鸽子模块
 * 核心业务逻辑：签到、爽约记录、限制发布
 *
 * 包含：
 * - openCheckinWindow    见面时间到 → 开启签到窗口（定时触发）
 * - submitCheckin        用户提交签到
 * - onCheckinTimeout     签到窗口关闭 → 判断爽约（定时触发）
 * - onMatchComplete      双方签到成功 → 触发后续流程
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { _generateRecapCard } = require('./ai');
const { _sendNotification } = require('./notifications');
const { _createSafetyAlert } = require('./safety');

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 每 5 分钟检查：是否有搭子到了见面时间 → 开启签到窗口
// M-8 优化：从每分钟降低到每 5 分钟，减少全表扫描 Firestore 成本
// ─────────────────────────────────────────────────────
exports.openCheckinWindow = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 5 minutes')
  .onRun(async () => {
    const now = Timestamp.now();
    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);

    // 找出"已确认"且见面时间在过去30分钟内，但签到窗口未开启的搭子
    const matches = await db.collection('matches')
      .where('status', '==', 'confirmed')
      .where('checkinWindowOpen', '==', false)
      .where('meetTime', '<=', now)
      .where('meetTime', '>=', Timestamp.fromDate(thirtyMinAgo))
      .get();

    const batch = db.batch();
    const notifications = [];

    matches.forEach(doc => {
      batch.update(doc.ref, {
        checkinWindowOpen: true,
        checkinWindowExpiresAt: Timestamp.fromDate(
          new Date(doc.data().meetTime.toDate().getTime() + 60 * 60 * 1000) // 1小时签到窗口
        ),
      });

      // 通知每位参与者去签到
      doc.data().participants.forEach(uid => {
        notifications.push({ uid, matchId: doc.id, postId: doc.data().postId });
      });
    });

    await batch.commit();

    // 发送推送通知
    await Promise.all(notifications.map(n => _sendCheckinNotification(n.uid, n.matchId)));

    console.log(`开启签到窗口：${matches.size} 个搭子`);
  });

// ─────────────────────────────────────────────────────
// 用户提交签到（可调用函数）
// 支持 GPS 验证（前端传入经纬度，后端验证距离）
// ─────────────────────────────────────────────────────
exports.submitCheckin = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId, lat, lng } = data;
    const uid = context.auth.uid;

    // H-4 + M-1: 签到逻辑全部收进 runTransaction，CAS 保证"最后一人签到→completed"
    // 只触发一次；GPS 在 post.location.lat/lng 存在时强制客户端上报坐标（防绕过）。
    let allCheckedIn = false;
    let committedMatch = null;

    await db.runTransaction(async (tx) => {
      const matchRef = db.collection('matches').doc(matchId);
      const matchDoc = await tx.get(matchRef);
      if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');
      const match = matchDoc.data();

      if (!match.participants.includes(uid)) {
        throw new functions.https.HttpsError('permission-denied', '你不是该搭子的参与者');
      }
      if (match.status !== 'confirmed') {
        throw new functions.https.HttpsError('failed-precondition', '搭子状态不允许签到');
      }
      if (!match.checkinWindowOpen) {
        throw new functions.https.HttpsError('failed-precondition', '签到窗口未开启');
      }
      if ((match.checkedIn || []).includes(uid)) {
        throw new functions.https.HttpsError('already-exists', '你已经签到过了');
      }

      // 读 post 拿到坐标（在事务内一并读取保持一致性快照）
      const postRef = db.collection('posts').doc(match.postId);
      const postDoc = await tx.get(postRef);
      if (!postDoc.exists) {
        throw new functions.https.HttpsError('not-found', '帖子不存在');
      }
      const post = postDoc.data();
      const postLat = post.location && post.location.lat;
      const postLng = post.location && post.location.lng;

      // M-1: 帖子保存了坐标则客户端必须上报 lat/lng，不接受"不传坐标绕过"
      if (typeof postLat === 'number' && typeof postLng === 'number') {
        if (typeof lat !== 'number' || typeof lng !== 'number') {
          throw new functions.https.HttpsError(
            'invalid-argument',
            '该活动要求定位签到，请开启位置权限后重试'
          );
        }
        const distance = _calcDistance(lat, lng, postLat, postLng);
        if (distance > 500) {
          throw new functions.https.HttpsError(
            'out-of-range',
            `距离活动地点 ${Math.round(distance)}m，需在 500m 内才能签到`
          );
        }
      }

      // 在事务内判断签到完成后是否全员到齐，CAS 转 completed + increment totalMeetups
      const newCheckedIn = [...(match.checkedIn || []), uid];
      const allDone = match.participants.every((p) => newCheckedIn.includes(p));

      if (allDone) {
        tx.update(matchRef, {
          checkedIn: newCheckedIn,
          status: 'completed',
          checkinWindowOpen: false,
          completedAt: FieldValue.serverTimestamp(),
        });
        tx.update(postRef, { status: 'done' });
        for (const p of match.participants) {
          tx.update(db.collection('users').doc(p), {
            totalMeetups: FieldValue.increment(1),
          });
        }
        allCheckedIn = true;
        committedMatch = { ...match, checkedIn: newCheckedIn, status: 'completed' };
      } else {
        tx.update(matchRef, { checkedIn: newCheckedIn });
      }
    });

    // 事务外做非核心副作用（推送、押金释放、回忆卡、勋章）——不影响一致性
    if (allCheckedIn && committedMatch) {
      try {
        await _releaseDeposits(matchId);
      } catch (err) {
        console.error(`押金释放失败 matchId=${matchId}:`, err);
      }
      _generateRecapCard(matchId).catch((err) =>
        console.error(`回忆卡生成失败 matchId=${matchId}:`, err)
      );
      await Promise.all(
        committedMatch.participants.map((p) => _sendReviewReadyNotification(p, matchId))
      );
      // 延迟发送快速反馈提醒（给用户时间先完成评价流程）
      await Promise.all(
        committedMatch.participants.map((p) => _sendQuickFeedbackNotification(p, matchId))
      );
      await Promise.all(committedMatch.participants.map((p) => _checkAndAwardBadges(p)));
    }

    return { success: true, allCheckedIn };
  });

// ─────────────────────────────────────────────────────
// 每5分钟检查：签到窗口是否超时 → 判断爽约
// ─────────────────────────────────────────────────────
exports.onCheckinTimeout = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 5 minutes')
  .onRun(async () => {
    const now = Timestamp.now();

    const expiredMatches = await db.collection('matches')
      .where('status', '==', 'confirmed')
      .where('checkinWindowOpen', '==', true)
      .where('checkinWindowExpiresAt', '<=', now)
      .get();

    for (const doc of expiredMatches.docs) {
      const match = doc.data();
      const ghosted = match.participants.filter(
        uid => !match.checkedIn || !match.checkedIn.includes(uid)
      );

      // 已签到的人正常完成
      const attended = match.participants.filter(
        uid => match.checkedIn && match.checkedIn.includes(uid)
      );

      const batch = db.batch();

      // 更新 match 状态
      batch.update(doc.ref, {
        status: ghosted.length === match.participants.length ? 'ghosted_all' : 'ghosted',
        checkinWindowOpen: false,
        ghostedUsers: ghosted,
        attendedUsers: attended,
        resolvedAt: FieldValue.serverTimestamp(),
      });

      // H-5: 爽约计数用 FieldValue.increment（原 read-modify-write 在并发下会丢失更新）。
      // isRestricted 改为在 applyToPost 入口实时判定 `ghostCount >= 3`，避免为了算出
      // newCount 又引入新触发器。isRestricted 字段仍保留作为手动封禁标记。
      for (const uid of ghosted) {
        const userRef = db.collection('users').doc(uid);
        batch.update(userRef, {
          ghostCount: FieldValue.increment(1),
        });
      }

      await batch.commit();

      // 处理押金扣除
      if (ghosted.length > 0) {
        await _processGhostDeposits(doc.id, ghosted, attended);
      }

      // 通知双方结果
      await Promise.all([
        ...ghosted.map(uid => _sendGhostedNotification(uid, doc.id)),
        ...attended.map(uid => _sendAttendedNotification(uid, doc.id)),
      ]);

      // 向所有参与者发送快速反馈提醒（含被爽约和签到者）
      await Promise.all(
        match.participants.map(uid => _sendQuickFeedbackNotification(uid, doc.id))
      );

      // 为未签到用户创建安全提醒（有紧急联系人时触发）
      await Promise.all(
        ghosted.map(uid => _createSafetyAlert(doc.id, uid).catch(err =>
          console.error(`安全提醒创建失败 matchId=${doc.id}, uid=${uid}:`, err)
        ))
      );
    }

    console.log(`签到超时处理：${expiredMatches.size} 个搭子`);
  });

// ─────────────────────────────────────────────────────
// 内部：勋章检查
// ─────────────────────────────────────────────────────
async function _checkAndAwardBadges(uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  const user = userDoc.data();
  const newBadges = [];

  // 🌱 新搭子主：完成首次搭子
  if (user.totalMeetups >= 1 && !user.badges.includes('new_host')) {
    newBadges.push('new_host');
  }

  // ⭐ 靠谱搭子主：0次爽约 + 完成5次
  if (user.totalMeetups >= 5 && user.ghostCount === 0 && !user.badges.includes('reliable_host')) {
    newBadges.push('reliable_host');
  }

  // 🏆 金牌搭子主：评分4.8+，完成20次，0次爽约
  if (
    user.totalMeetups >= 20 &&
    user.ghostCount === 0 &&
    user.rating >= 4.8 &&
    !user.badges.includes('gold_host')
  ) {
    newBadges.push('gold_host');
  }

  if (newBadges.length > 0) {
    await db.collection('users').doc(uid).update({
      badges: FieldValue.arrayUnion(...newBadges),
    });
  }
}

// ─────────────────────────────────────────────────────
// 内部：GPS 距离计算（Haversine 公式，单位：米）
// ─────────────────────────────────────────────────────
function _calcDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ─────────────────────────────────────────────────────
// 占位：押金处理（在 deposits.js 中实现）
// ─────────────────────────────────────────────────────
async function _processGhostDeposits(matchId, ghostedUids, attendedUids) {
  console.log(`押金扣除 matchId=${matchId}, ghosted=${ghostedUids}, attended=${attendedUids}`);
  // TODO: 调用微信/支付宝担保交易接口完成实际扣款
}

async function _releaseDeposits(matchId) {
  console.log(`押金释放 matchId=${matchId}`);
  // TODO: 调用微信/支付宝接口解冻押金
}

// ─────────────────────────────────────────────────────
// 占位：推送通知（在 notifications.js 中实现）
// ─────────────────────────────────────────────────────
async function _sendCheckinNotification(uid, matchId) {
  await _sendNotification(uid, '签到提醒', '搭子活动开始了，快来签到吧！', { type: 'checkin', matchId });
}
async function _sendGhostedNotification(uid, matchId) {
  await _sendNotification(uid, '未签到提醒', '你错过了一次搭子活动，请注意按时签到', { type: 'ghosted', matchId });
}
async function _sendAttendedNotification(uid, matchId) {
  await _sendNotification(uid, '活动完成', '搭子到了但对方未到，你的信用不受影响', { type: 'attended', matchId });
}
async function _sendReviewReadyNotification(uid, matchId) {
  await _sendNotification(uid, '快来评价吧', '搭子活动已完成，给对方一个评价吧！', { type: 'review_ready', matchId });
}
async function _sendQuickFeedbackNotification(uid, matchId) {
  await _sendNotification(uid, '见到搭子了吗？', '活动结束了，告诉我们你是否见到了对方 👋', { type: 'quick_feedback', matchId });
}

// ─────────────────────────────────────────────────────
// 提交快速反馈：见到了 / 没见到（Hinge "We Met?" 模式）
// 用于匹配算法训练信号，比完整评价更轻量
// ─────────────────────────────────────────────────────
exports.submitQuickFeedback = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId, feedback } = data;
    const uid = context.auth.uid;

    if (!matchId) throw new functions.https.HttpsError('invalid-argument', '缺少 matchId');
    if (!['met', 'no_show'].includes(feedback)) {
      throw new functions.https.HttpsError('invalid-argument', 'feedback 必须是 "met" 或 "no_show"');
    }

    return await db.runTransaction(async (tx) => {
      const matchRef = db.collection('matches').doc(matchId);
      const matchDoc = await tx.get(matchRef);

      if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');

      const match = matchDoc.data();

      if (!match.participants.includes(uid)) {
        throw new functions.https.HttpsError('permission-denied', '你不是该搭子的参与者');
      }

      // 只允许在 completed 或 ghosted 状态下提交反馈
      if (!['completed', 'ghosted', 'ghosted_all'].includes(match.status)) {
        throw new functions.https.HttpsError('failed-precondition', '搭子尚未结束，无法提交反馈');
      }

      // 检查是否已提交过
      const existing = match.quickFeedback || {};
      if (existing[uid]) {
        throw new functions.https.HttpsError('already-exists', '你已经提交过反馈了');
      }

      // 用点路径写入 quickFeedback.{uid}，只修改自己的 key
      tx.update(matchRef, {
        [`quickFeedback.${uid}`]: feedback,
      });

      return { success: true };
    });
  });
