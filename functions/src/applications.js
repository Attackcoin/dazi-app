/**
 * 申请管理模块
 * 处理：提交申请、接受/拒绝、候补、24h自动过期、男女比例校验
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 提交申请（含男女比例校验）
// ─────────────────────────────────────────────────────
exports.applyToPost = functions
  .region('asia-southeast1')
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

      // H-1: 确定性 docId = `${postId}_${uid}`，防止并发两次 applyToPost 调用
      // 都看到"existingApp empty"然后各自创建申请。事务内 tx.get 即可保证原子。
      const appRef = db.collection('applications').doc(`${postId}_${uid}`);
      const existingAppDoc = await tx.get(appRef);
      if (existingAppDoc.exists
          && ['pending', 'accepted', 'waitlisted'].includes(existingAppDoc.data().status)) {
        throw new functions.https.HttpsError('already-exists', '你已经申请过这个搭子了');
      }

      // 检查用户是否被限制（爽约3次或手动封禁）
      // H-5 配套：isRestricted 字段不再由 antiGhosting 实时维护，改为此处判定 ghostCount 阈值
      const userDoc = await tx.get(db.collection('users').doc(uid));
      const user = userDoc.data();
      if (user.isRestricted || (user.ghostCount || 0) >= 3) {
        throw new functions.https.HttpsError('permission-denied', '你的账号因爽约次数过多已被限制');
      }

      // 统计当前已接受的人数
      const acceptedCount = Object.values(post.acceptedGender || {}).reduce((a, b) => a + b, 0);
      const totalAccepted = acceptedCount; // 不含发布者

      let status = 'pending';

      // 判断是进入候补还是正常申请
      if (totalAccepted >= post.totalSlots - 1) {
        // 已满，进候补
        tx.update(postRef, {
          waitlist: FieldValue.arrayUnion(uid),
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
            waitlist: FieldValue.arrayUnion(uid),
          });
          status = 'waitlisted';
        }
      }

      // 创建申请记录（使用上面确定性 docId，H-1 防并发重复申请）
      tx.set(appRef, {
        postId,
        applicantId: uid,
        status,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromDate(
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
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { applicationId } = data;

    // M-9: 事务外 pre-fetch 其它 pending 申请（事务内不能做 where query）。
    // 这会有窗口：pre-fetch 与事务之间新到的申请仍会遗留 pending，
    // 由 24h expireApplications 定时器兜底。
    const appRefEarly = db.collection('applications').doc(applicationId);
    const appDocEarly = await appRefEarly.get();
    if (!appDocEarly.exists) {
      throw new functions.https.HttpsError('not-found', '申请不存在');
    }
    const earlyPostId = appDocEarly.data().postId;
    const otherPendingSnap = await db.collection('applications')
      .where('postId', '==', earlyPostId)
      .where('status', '==', 'pending')
      .get();
    const otherPendingRefs = otherPendingSnap.docs
      .filter((d) => d.id !== applicationId)
      .map((d) => d.ref);

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
        [`acceptedGender.${genderKey}`]: FieldValue.increment(1),
      });

      // 检查是否满员，更新 post 状态
      const newTotal = Object.values(post.acceptedGender || {}).reduce((a, b) => a + b, 0) + 1;
      if (newTotal >= post.totalSlots - 1) {
        tx.update(postRef, { status: 'full' });
        // M-9: 满员后批量自动拒绝其它 pending 申请
        for (const ref of otherPendingRefs) {
          tx.update(ref, { status: 'auto_rejected' });
        }
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
        lastMessageAt: FieldValue.serverTimestamp(),
        lastMessagePreview: '',
        createdAt: FieldValue.serverTimestamp(),
      });

      return { success: true, matchId: matchRef.id };
    });
  });

// ─────────────────────────────────────────────────────
// 发布者拒绝申请
// ─────────────────────────────────────────────────────
exports.rejectApplication = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { applicationId, reason } = data;

    return await db.runTransaction(async (tx) => {
      const appRef = db.collection('applications').doc(applicationId);
      const appDoc = await tx.get(appRef);

      if (!appDoc.exists) throw new functions.https.HttpsError('not-found', '申请不存在');

      const app = appDoc.data();
      if (app.status !== 'pending') throw new functions.https.HttpsError('failed-precondition', '该申请已被处理');

      const postRef = db.collection('posts').doc(app.postId);
      const postDoc = await tx.get(postRef);

      if (postDoc.data().userId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', '只有发布者可以拒绝申请');
      }

      tx.update(appRef, { status: 'rejected', rejectReason: reason || null });
      return { success: true };
    });
  });

// ─────────────────────────────────────────────────────
// 申请者撤回自己的申请
// ─────────────────────────────────────────────────────
exports.withdrawApplication = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { applicationId } = data;
    if (!applicationId) throw new functions.https.HttpsError('invalid-argument', '缺少 applicationId');

    return await db.runTransaction(async (tx) => {
      const appRef = db.collection('applications').doc(applicationId);
      const appDoc = await tx.get(appRef);

      if (!appDoc.exists) throw new functions.https.HttpsError('not-found', '申请不存在');

      const app = appDoc.data();
      if (app.applicantId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', '只能撤回自己的申请');
      }
      if (app.status !== 'pending') {
        throw new functions.https.HttpsError('failed-precondition', '该申请已被处理，无法撤回');
      }

      tx.update(appRef, { status: 'withdrawn' });
      return { success: true };
    });
  });

// ─────────────────────────────────────────────────────
// 每小时检查：24h 未回应的申请自动过期
// ─────────────────────────────────────────────────────
exports.expireApplications = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 60 minutes')
  .onRun(async () => {
    const now = Timestamp.now();

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
  .region('asia-southeast1')
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
    // H-2: toUserId 必须是同 match 的其他参与者（防止污染任意用户评分）
    if (!match.participants.includes(toUserId) || toUserId === fromUid) {
      throw new functions.https.HttpsError('permission-denied', 'toUserId 必须为该搭子的其他参与者');
    }
    if (match.status !== 'completed') {
      throw new functions.https.HttpsError('failed-precondition', '搭子尚未完成');
    }

    // 防止重复评价：使用复合文档 ID（与 Firestore rules 层保持一致）
    const reviewDocId = `${matchId}_${fromUid}_${toUserId}`;
    const reviewRef = db.collection('reviews').doc(reviewDocId);

    // H-3: 评价写入 + 被评价者 ratingSum/ratingCount 更新必须在同一事务内原子提交，
    // 防止"写入 review 成功但 rating 聚合失败"的部分成功导致的脏数据
    await db.runTransaction(async (tx) => {
      const existingReview = await tx.get(reviewRef);
      if (existingReview.exists) {
        throw new functions.https.HttpsError('already-exists', '你已经评价过了');
      }
      tx.set(reviewRef, {
        matchId,
        fromUser: fromUid,
        toUser: toUserId,
        rating,
        comment: comment || '',
        tags: tags || [],
        createdAt: FieldValue.serverTimestamp(),
      });
      // 原子增量：ratingSum += rating, ratingCount += 1
      // 前端展示 rating = ratingSum / ratingCount（均值）
      tx.update(db.collection('users').doc(toUserId), {
        ratingSum: FieldValue.increment(rating),
        ratingCount: FieldValue.increment(1),
      });
    });

    return { success: true };
  });
