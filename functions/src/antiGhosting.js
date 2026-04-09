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
const { _generateRecapCard } = require('./ai');

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 每分钟检查：是否有搭子到了见面时间 → 开启签到窗口
// ─────────────────────────────────────────────────────
exports.openCheckinWindow = functions
  .region('asia-east1')
  .pubsub.schedule('every 1 minutes')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const thirtyMinAgo = new Date(Date.now() - 30 * 60 * 1000);

    // 找出"已确认"且见面时间在过去30分钟内，但签到窗口未开启的搭子
    const matches = await db.collection('matches')
      .where('status', '==', 'confirmed')
      .where('checkinWindowOpen', '==', false)
      .where('meetTime', '<=', now)
      .where('meetTime', '>=', admin.firestore.Timestamp.fromDate(thirtyMinAgo))
      .get();

    const batch = db.batch();
    const notifications = [];

    matches.forEach(doc => {
      batch.update(doc.ref, {
        checkinWindowOpen: true,
        checkinWindowExpiresAt: admin.firestore.Timestamp.fromDate(
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
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId, lat, lng } = data;
    const uid = context.auth.uid;

    const matchDoc = await db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');

    const match = matchDoc.data();

    if (!match.participants.includes(uid)) {
      throw new functions.https.HttpsError('permission-denied', '你不是该搭子的参与者');
    }
    if (!match.checkinWindowOpen) {
      throw new functions.https.HttpsError('failed-precondition', '签到窗口未开启');
    }
    if (match.checkedIn && match.checkedIn.includes(uid)) {
      throw new functions.https.HttpsError('already-exists', '你已经签到过了');
    }

    // GPS 验证（误差 < 500m 视为有效）
    // 仅当客户端传入坐标 AND 帖子本身保存了坐标时才做距离验证，
    // 否则退化为"信任签到"（见 create_post_screen TODO：Maps picker 未接入前无坐标）。
    if (lat && lng) {
      const postDoc = await db.collection('posts').doc(match.postId).get();
      const post = postDoc.data();
      const postLat = post.location && post.location.lat;
      const postLng = post.location && post.location.lng;
      if (typeof postLat === 'number' && typeof postLng === 'number') {
        const distance = _calcDistance(lat, lng, postLat, postLng);
        if (distance > 500) {
          throw new functions.https.HttpsError(
            'out-of-range',
            `距离活动地点 ${Math.round(distance)}m，需在 500m 内才能签到`
          );
        }
      }
    }

    // 记录签到
    await matchDoc.ref.update({
      checkedIn: admin.firestore.FieldValue.arrayUnion(uid),
    });

    // 检查是否所有人都签到了
    const updatedMatch = (await matchDoc.ref.get()).data();
    const allCheckedIn = match.participants.every(p => updatedMatch.checkedIn.includes(p));

    if (allCheckedIn) {
      await _onAllCheckedIn(matchId, updatedMatch);
    }

    return { success: true, allCheckedIn };
  });

// ─────────────────────────────────────────────────────
// 每5分钟检查：签到窗口是否超时 → 判断爽约
// ─────────────────────────────────────────────────────
exports.onCheckinTimeout = functions
  .region('asia-east1')
  .pubsub.schedule('every 5 minutes')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

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
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 爽约用户 ghostCount +1，触发限制检查
      for (const uid of ghosted) {
        const userRef = db.collection('users').doc(uid);
        const userDoc = await userRef.get();
        const newCount = (userDoc.data().ghostCount || 0) + 1;
        batch.update(userRef, {
          ghostCount: newCount,
          isRestricted: newCount >= 3,
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
    }

    console.log(`签到超时处理：${expiredMatches.size} 个搭子`);
  });

// ─────────────────────────────────────────────────────
// 内部：所有人签到成功后的处理
// ─────────────────────────────────────────────────────
async function _onAllCheckedIn(matchId, match) {
  const batch = db.batch();
  const matchRef = db.collection('matches').doc(matchId);

  batch.update(matchRef, {
    status: 'completed',
    checkinWindowOpen: false,
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 所有参与者 totalMeetups +1
  for (const uid of match.participants) {
    batch.update(db.collection('users').doc(uid), {
      totalMeetups: admin.firestore.FieldValue.increment(1),
    });
  }

  // 对应的 post 状态更新为 done
  batch.update(db.collection('posts').doc(match.postId), { status: 'done' });

  await batch.commit();

  // 释放押金
  await _releaseDeposits(matchId);

  // 生成回忆卡（后台异步，不阻塞签到流程）
  _generateRecapCard(matchId).catch(err =>
    console.error(`回忆卡生成失败 matchId=${matchId}:`, err)
  );

  // 推送"可以评价了"通知
  await Promise.all(
    match.participants.map(uid => _sendReviewReadyNotification(uid, matchId))
  );

  // 检查并更新勋章
  await Promise.all(match.participants.map(uid => _checkAndAwardBadges(uid)));
}

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
      badges: admin.firestore.FieldValue.arrayUnion(...newBadges),
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
async function _sendCheckinNotification(uid, matchId) {}
async function _sendGhostedNotification(uid, matchId) {}
async function _sendAttendedNotification(uid, matchId) {}
async function _sendReviewReadyNotification(uid, matchId) {}
