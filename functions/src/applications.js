/**
 * 申请管理模块
 * 处理：提交申请、接受/拒绝、候补、24h自动过期、男女比例校验
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 提交申请（含男女比例校验）
// ─────────────────────────────────────────────────────
exports.applyToPost = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { postId } = data;
    const uid = context.auth.uid;

    // 在事务中处理，防止并发冲突
    return await db.runTransaction(async (tx) => {
      const postRef = db.collection('posts').doc(postId);
      const postDoc = await tx.get(postRef);

      if (!postDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');

      const post = postDoc.data();

      if (post.userId === uid) throw new functions.https.HttpsError('invalid-argument', '不能申请自己发布的搭子');
      if (post.status !== 'open') throw new functions.https.HttpsError('failed-precondition', '该搭子已满员或已结束');

      // 检查用户是否已申请过
      const existingApp = await db.collection('applications')
        .where('postId', '==', postId)
        .where('applicantId', '==', uid)
        .where('status', 'in', ['pending', 'accepted'])
        .limit(1)
        .get();

      if (!existingApp.empty) throw new functions.https.HttpsError('already-exists', '你已经申请过这个搭子了');

      // 检查用户是否被限制（爽约3次）
      const userDoc = await tx.get(db.collection('users').doc(uid));
      const user = userDoc.data();
      if (user.isRestricted) throw new functions.https.HttpsError('permission-denied', '你的账号因爽约次数过多已被限制');

      // 统计当前已接受的人数
      const acceptedCount = Object.values(post.acceptedGender || {}).reduce((a, b) => a + b, 0);
      const totalAccepted = acceptedCount; // 不含发布者

      let status = 'pending';

      // 判断是进入候补还是正常申请
      if (totalAccepted >= post.totalSlots - 1) {
        // 已满，进候补
        tx.update(postRef, {
          waitlist: admin.firestore.FieldValue.arrayUnion(uid),
        });
        status = 'waitlisted';
      } else if (post.genderQuota) {
        // 有男女比例限制，检查该性别是否已满
        const userGender = user.gender; // male/female/other
        const quotaKey = userGender === 'female' ? 'female' : 'male';
        const acceptedForGender = (post.acceptedGender || {})[quotaKey] || 0;
        const quotaForGender = (post.genderQuota || {})[quotaKey] || 0;

        if (quotaForGender > 0 && acceptedForGender >= quotaForGender) {
          // 该性别已满，进候补
          tx.update(postRef, {
            waitlist: admin.firestore.FieldValue.arrayUnion(uid),
          });
          status = 'waitlisted';
        }
      }

      // 创建申请记录
      const appRef = db.collection('applications').doc();
      tx.set(appRef, {
        postId,
        applicantId: uid,
        status,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 24 * 60 * 60 * 1000)
        ),
      });

      return { success: true, applicationId: appRef.id, status };
    });
  });

// ─────────────────────────────────────────────────────
// 发布者接受申请
// ─────────────────────────────────────────────────────
exports.acceptApplication = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { applicationId } = data;

    return await db.runTransaction(async (tx) => {
      const appRef = db.collection('applications').doc(applicationId);
      const appDoc = await tx.get(appRef);

      if (!appDoc.exists) throw new functions.https.HttpsError('not-found', '申请不存在');

      const app = appDoc.data();
      const postRef = db.collection('posts').doc(app.postId);
      const postDoc = await tx.get(postRef);
      const post = postDoc.data();

      // 验证是发布者在操作
      if (post.userId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', '只有发布者可以接受申请');
      }

      // 获取申请者 + 发布者信息（用于性别统计 + 冗余写入 match 文档）
      const [applicantDoc, ownerDoc] = await Promise.all([
        tx.get(db.collection('users').doc(app.applicantId)),
        tx.get(db.collection('users').doc(post.userId)),
      ]);
      const applicant = applicantDoc.data();
      const owner = ownerDoc.data() || {};
      const genderKey = applicant.gender === 'female' ? 'female' : 'male';

      // 更新申请状态
      tx.update(appRef, { status: 'accepted' });

      // 更新 post 的已接受性别计数
      tx.update(postRef, {
        [`acceptedGender.${genderKey}`]: admin.firestore.FieldValue.increment(1),
      });

      // 检查是否满员，更新 post 状态
      const newTotal = Object.values(post.acceptedGender || {}).reduce((a, b) => a + b, 0) + 1;
      if (newTotal >= post.totalSlots - 1) {
        tx.update(postRef, { status: 'full' });
      }

      // 创建 match 记录（触发聊天室开启）
      // 冗余写入 postTitle / postCategory / participantInfo，避免前端再做 join。
      const matchRef = db.collection('matches').doc();
      tx.set(matchRef, {
        postId: app.postId,
        chatId: matchRef.id, // chat ID 与 match ID 相同，简化架构
        participants: [post.userId, app.applicantId],
        participantInfo: {
          [post.userId]: {
            uid: post.userId,
            name: owner.name || '',
            avatar: owner.avatar || '',
          },
          [app.applicantId]: {
            uid: app.applicantId,
            name: applicant.name || '',
            avatar: applicant.avatar || '',
          },
        },
        postTitle: post.title || '',
        postCategory: post.category || '',
        checkedIn: [],
        checkinWindowOpen: false,
        depositStatus: post.depositAmount > 0 ? 'pending' : 'none',
        status: 'confirmed',
        meetTime: post.time,
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessagePreview: '',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, matchId: matchRef.id };
    });
  });

// ─────────────────────────────────────────────────────
// 发布者拒绝申请
// ─────────────────────────────────────────────────────
exports.rejectApplication = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { applicationId, reason } = data;
    const appRef = db.collection('applications').doc(applicationId);
    const appDoc = await appRef.get();

    if (!appDoc.exists) throw new functions.https.HttpsError('not-found', '申请不存在');

    const app = appDoc.data();
    const postDoc = await db.collection('posts').doc(app.postId).get();

    if (postDoc.data().userId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', '只有发布者可以拒绝申请');
    }

    await appRef.update({ status: 'rejected', rejectReason: reason || null });
    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 每小时检查：24h 未回应的申请自动过期
// ─────────────────────────────────────────────────────
exports.expireApplications = functions
  .region('asia-east1')
  .pubsub.schedule('every 60 minutes')
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const expiredApps = await db.collection('applications')
      .where('status', '==', 'pending')
      .where('expiresAt', '<=', now)
      .get();

    const batch = db.batch();
    expiredApps.forEach(doc => {
      batch.update(doc.ref, { status: 'expired' });
    });

    await batch.commit();
    console.log(`申请过期处理：${expiredApps.size} 条`);
  });

// ─────────────────────────────────────────────────────
// 提交评价（签到完成后可用）
// ─────────────────────────────────────────────────────
exports.submitReview = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId, toUserId, rating, comment, tags } = data;
    const fromUid = context.auth.uid;

    if (rating < 1 || rating > 5) throw new functions.https.HttpsError('invalid-argument', '评分需在 1-5 之间');

    const matchDoc = await db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');

    const match = matchDoc.data();
    if (!match.participants.includes(fromUid)) {
      throw new functions.https.HttpsError('permission-denied', '你不是该搭子的参与者');
    }
    if (match.status !== 'completed') {
      throw new functions.https.HttpsError('failed-precondition', '搭子尚未完成');
    }

    // 防止重复评价
    const existingReview = await db.collection('reviews')
      .where('matchId', '==', matchId)
      .where('fromUser', '==', fromUid)
      .where('toUser', '==', toUserId)
      .limit(1)
      .get();

    if (!existingReview.empty) throw new functions.https.HttpsError('already-exists', '你已经评价过了');

    // 写入评价
    await db.collection('reviews').add({
      matchId,
      fromUser: fromUid,
      toUser: toUserId,
      rating,
      comment: comment || '',
      tags: tags || [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 重新计算被评价者的平均分
    const allReviews = await db.collection('reviews')
      .where('toUser', '==', toUserId)
      .get();

    const total = allReviews.docs.reduce((sum, d) => sum + d.data().rating, 0);
    const avg = total / allReviews.size;

    await db.collection('users').doc(toUserId).update({
      rating: Math.round(avg * 10) / 10,
      reviewCount: allReviews.size,
    });

    return { success: true };
  });
