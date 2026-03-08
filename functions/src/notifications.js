/**
 * 推送通知模块
 * 12 种推送场景，全部通过 Firebase Cloud Messaging (FCM) 发送
 *
 * 使用方式：
 * 1. 用户设备注册 FCM Token → 存储到 users/{uid}.fcmToken
 * 2. 调用本模块函数触发推送
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────
// 内部：发送推送通知
// ─────────────────────────────────────────────────────
async function sendNotification(uid, title, body, data = {}) {
  const userDoc = await db.collection('users').doc(uid).get();
  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) return; // 用户未注册设备Token，跳过

  await messaging.send({
    token: fcmToken,
    notification: { title, body },
    data,
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });
}

// ─────────────────────────────────────────────────────
// 注册/更新 FCM Token（前端每次启动时调用）
// ─────────────────────────────────────────────────────
exports.registerFcmToken = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { token } = data;
    await db.collection('users').doc(context.auth.uid).update({ fcmToken: token });
    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 监听新申请 → 通知发布者
// ─────────────────────────────────────────────────────
exports.onNewApplication = functions
  .region('asia-east1')
  .firestore.document('applications/{appId}')
  .onCreate(async (snap) => {
    const app = snap.data();
    if (app.status !== 'pending') return; // 候补不通知

    const postDoc = await db.collection('posts').doc(app.postId).get();
    const post = postDoc.data();

    const applicantDoc = await db.collection('users').doc(app.applicantId).get();
    const applicant = applicantDoc.data();

    await sendNotification(
      post.userId,
      '有人想加入你的搭子 👀',
      `${applicant.name} 想参加「${post.title}」，去看看`,
      { type: 'new_application', applicationId: snap.id, postId: app.postId }
    );
  });

// ─────────────────────────────────────────────────────
// 监听申请状态变化 → 通知申请者
// ─────────────────────────────────────────────────────
exports.onApplicationStatusChange = functions
  .region('asia-east1')
  .firestore.document('applications/{appId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === after.status) return;

    const postDoc = await db.collection('posts').doc(after.postId).get();
    const post = postDoc.data();

    if (after.status === 'accepted') {
      await sendNotification(
        after.applicantId,
        '申请通过啦 🎉',
        `恭喜！你已加入「${post.title}」，${_formatTime(post.time)} 见`,
        { type: 'application_accepted', postId: after.postId }
      );
    } else if (after.status === 'rejected') {
      await sendNotification(
        after.applicantId,
        '这次没赶上',
        `「${post.title}」这次没通过，还有其他搭子等你`,
        { type: 'application_rejected' }
      );
    } else if (after.status === 'waitlisted') {
      await sendNotification(
        after.applicantId,
        '已加入候补',
        `「${post.title}」当前已满，你在候补名单，有空位会第一时间通知你`,
        { type: 'waitlisted', postId: after.postId }
      );
    }
  });

// ─────────────────────────────────────────────────────
// 每天检查：搭子开始前 2 小时发提醒
// ─────────────────────────────────────────────────────
exports.sendPreMeetingReminder = functions
  .region('asia-east1')
  .pubsub.schedule('every 30 minutes')
  .onRun(async () => {
    const now = new Date();
    const twoHoursLater = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    const twoAndHalfHoursLater = new Date(now.getTime() + 2.5 * 60 * 60 * 1000);

    const matches = await db.collection('matches')
      .where('status', '==', 'confirmed')
      .where('meetTime', '>=', admin.firestore.Timestamp.fromDate(twoHoursLater))
      .where('meetTime', '<=', admin.firestore.Timestamp.fromDate(twoAndHalfHoursLater))
      .get();

    for (const doc of matches.docs) {
      const match = doc.data();
      const postDoc = await db.collection('posts').doc(match.postId).get();
      const post = postDoc.data();

      await Promise.all(
        match.participants.map(uid =>
          sendNotification(
            uid,
            '搭子快开始了 ⏰',
            `「${post.title}」2小时后开始，记得准时到哦`,
            { type: 'pre_meeting_reminder', matchId: doc.id }
          )
        )
      );
    }
  });

// ─────────────────────────────────────────────────────
// 监听月报生成 → 通知用户
// ─────────────────────────────────────────────────────
exports.onMonthlyReportGenerated = functions
  .region('asia-east1')
  .firestore.document('monthlyReports/{reportId}')
  .onCreate(async (snap) => {
    const report = snap.data();
    await sendNotification(
      report.userId,
      '你的月度搭子报告出炉了 🎉',
      `上个月完成了 ${report.meetups} 次搭子，认识了 ${report.newFriends} 位新朋友！`,
      { type: 'monthly_report', reportId: snap.id }
    );
  });

// ─────────────────────────────────────────────────────
// 工具：格式化时间显示
// ─────────────────────────────────────────────────────
function _formatTime(timestamp) {
  const date = timestamp.toDate();
  return date.toLocaleDateString('zh-CN', {
    month: 'long', day: 'numeric', weekday: 'long', hour: '2-digit', minute: '2-digit'
  });
}
