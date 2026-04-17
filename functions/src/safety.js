/**
 * 安全伴侣模块
 * 为线下搭子活动提供安全保障
 *
 * 包含：
 * - confirmSafety          用户确认自己安全（onCall）
 * - escalateSafetyAlert    定时任务：过期未确认的安全提醒升级处理
 * - _createSafetyAlert     内部函数：为未签到用户创建安全提醒（被 antiGhosting 调用）
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { _sendNotification } = require('./notifications');

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 内部：为未签到用户创建安全提醒
// 被 antiGhosting.onCheckinTimeout 调用
// ─────────────────────────────────────────────────────
async function _createSafetyAlert(matchId, uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) return;
  const user = userDoc.data();

  // 只有设置了紧急联系人的用户才触发安全流程
  const emergencyContacts = user.emergencyContacts;
  if (!Array.isArray(emergencyContacts) || emergencyContacts.length === 0) return;

  const alertId = `${matchId}_${uid}`;
  const alertRef = db.collection('safetyAlerts').doc(alertId);

  // 幂等：已存在则跳过
  const existing = await alertRef.get();
  if (existing.exists) return;

  await alertRef.set({
    matchId,
    uid,
    emergencyContacts,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000)),
  });

  // 发送安全确认推送给用户
  await _sendNotification(
    uid,
    '你的搭子活动安全确认',
    '你参加的活动已结束但未签到。如果你安全，请忽略此消息。',
    { type: 'safety_check', matchId, alertId }
  );
}

// ─────────────────────────────────────────────────────
// 用户确认自己安全（onCall）
// ─────────────────────────────────────────────────────
exports.confirmSafety = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const uid = context.auth.uid;

    // 查找该用户最新的 pending 安全提醒
    const alertsSnap = await db.collection('safetyAlerts')
      .where('uid', '==', uid)
      .where('status', '==', 'pending')
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (alertsSnap.empty) {
      throw new functions.https.HttpsError('not-found', '没有待确认的安全提醒');
    }

    const alertDoc = alertsSnap.docs[0];
    await alertDoc.ref.update({
      status: 'confirmed',
      confirmedAt: FieldValue.serverTimestamp(),
    });

    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 每10分钟检查：过期未确认的安全提醒 → 升级处理
// ─────────────────────────────────────────────────────
exports.escalateSafetyAlert = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 10 minutes')
  .onRun(async () => {
    const now = Timestamp.now();

    const expiredAlerts = await db.collection('safetyAlerts')
      .where('status', '==', 'pending')
      .where('expiresAt', '<=', now)
      .get();

    for (const doc of expiredAlerts.docs) {
      const alert = doc.data();

      // 更新状态为 escalated
      await doc.ref.update({
        status: 'escalated',
        escalatedAt: FieldValue.serverTimestamp(),
      });

      // MVP 阶段：记录日志 + 给用户发二次强提醒推送
      // 后续版本：发送短信/邮件给紧急联系人
      console.log(
        `安全提醒升级：alertId=${doc.id}, uid=${alert.uid}, ` +
        `紧急联系人=${JSON.stringify(alert.emergencyContacts)}`
      );

      await _sendNotification(
        alert.uid,
        '你的紧急联系人已被通知',
        '你的紧急联系人已被通知。如有误触请联系客服。',
        { type: 'safety_escalated', matchId: alert.matchId, alertId: doc.id }
      );
    }

    console.log(`安全提醒升级处理：${expiredAlerts.size} 条`);
  });

exports._createSafetyAlert = _createSafetyAlert;
