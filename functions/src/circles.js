/**
 * 兴趣圈子模块（T5-16）
 * 帖子体系之外的持久社群 — 解决搭子"用完即走"的留存问题
 *
 * 数据模型：
 *   circles/{circleId}
 *     name, description, category, icon, coverImage,
 *     memberCount, postCount, createdBy, createdAt
 *
 *   circles/{circleId}/members/{uid}
 *     joinedAt, role ('member' | 'admin' | 'owner')
 *
 *   circles/{circleId}/moments/{momentId}
 *     uid, text, images, createdAt
 *
 * 包含：
 * - createCircle       创建圈子 (onCall)
 * - joinCircle         加入圈子 (onCall)
 * - leaveCircle        退出圈子 (onCall)
 * - postMoment         发动态 (onCall)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

const MAX_CIRCLE_NAME = 30;
const MAX_CIRCLE_DESC = 500;
const MAX_MOMENT_TEXT = 1000;

// ─────────────────────────────────────────────────────
// 创建圈子
// ─────────────────────────────────────────────────────
exports.createCircle = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { name, description, category, icon } = data;

    if (!name || name.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', '圈子名称不能为空');
    }
    if (name.length > MAX_CIRCLE_NAME) {
      throw new functions.https.HttpsError('invalid-argument', `名称不能超过${MAX_CIRCLE_NAME}字`);
    }
    if (description && description.length > MAX_CIRCLE_DESC) {
      throw new functions.https.HttpsError('invalid-argument', `描述不能超过${MAX_CIRCLE_DESC}字`);
    }

    // 获取用户信息
    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.exists ? userDoc.data() : {};

    const circleRef = db.collection('circles').doc();
    const batch = db.batch();

    batch.set(circleRef, {
      name: name.trim(),
      description: (description || '').trim(),
      category: category || '',
      icon: icon || '',
      coverImage: '',
      memberCount: 1,
      postCount: 0,
      createdBy: uid,
      creatorName: user.name || '',
      createdAt: FieldValue.serverTimestamp(),
    });

    // 创建者自动成为 owner
    batch.set(circleRef.collection('members').doc(uid), {
      joinedAt: FieldValue.serverTimestamp(),
      role: 'owner',
      name: user.name || '',
      avatar: user.avatar || '',
    });

    await batch.commit();

    return { success: true, circleId: circleRef.id };
  });

// ─────────────────────────────────────────────────────
// 加入圈子
// ─────────────────────────────────────────────────────
exports.joinCircle = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { circleId } = data;

    if (!circleId) {
      throw new functions.https.HttpsError('invalid-argument', 'circleId 不能为空');
    }

    const circleRef = db.collection('circles').doc(circleId);
    const memberRef = circleRef.collection('members').doc(uid);

    // 幂等：已加入直接返回
    const existing = await memberRef.get();
    if (existing.exists) {
      return { success: true, alreadyMember: true };
    }

    const circleDoc = await circleRef.get();
    if (!circleDoc.exists) {
      throw new functions.https.HttpsError('not-found', '圈子不存在');
    }

    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.exists ? userDoc.data() : {};

    const batch = db.batch();

    batch.set(memberRef, {
      joinedAt: FieldValue.serverTimestamp(),
      role: 'member',
      name: user.name || '',
      avatar: user.avatar || '',
    });

    batch.update(circleRef, {
      memberCount: FieldValue.increment(1),
    });

    await batch.commit();

    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 退出圈子
// ─────────────────────────────────────────────────────
exports.leaveCircle = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { circleId } = data;

    if (!circleId) {
      throw new functions.https.HttpsError('invalid-argument', 'circleId 不能为空');
    }

    const circleRef = db.collection('circles').doc(circleId);
    const memberRef = circleRef.collection('members').doc(uid);

    const memberDoc = await memberRef.get();
    if (!memberDoc.exists) {
      return { success: true, notMember: true };
    }

    // owner 不能退出
    if (memberDoc.data().role === 'owner') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        '圈主不能退出圈子，请先转让圈主权限',
      );
    }

    const batch = db.batch();
    batch.delete(memberRef);
    batch.update(circleRef, {
      memberCount: FieldValue.increment(-1),
    });
    await batch.commit();

    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 发动态
// ─────────────────────────────────────────────────────
exports.postMoment = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { circleId, text, images } = data;

    if (!circleId) {
      throw new functions.https.HttpsError('invalid-argument', 'circleId 不能为空');
    }
    if (!text || text.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', '内容不能为空');
    }
    if (text.length > MAX_MOMENT_TEXT) {
      throw new functions.https.HttpsError('invalid-argument', `内容不能超过${MAX_MOMENT_TEXT}字`);
    }

    // 检查是否为成员
    const memberDoc = await db.collection('circles').doc(circleId)
      .collection('members').doc(uid).get();
    if (!memberDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', '你不是该圈子的成员');
    }

    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.exists ? userDoc.data() : {};

    const circleRef = db.collection('circles').doc(circleId);
    const momentRef = circleRef.collection('moments').doc();

    const batch = db.batch();
    batch.set(momentRef, {
      uid,
      authorName: user.name || '',
      authorAvatar: user.avatar || '',
      text: text.trim(),
      images: Array.isArray(images) ? images.slice(0, 9) : [],
      likeCount: 0,
      createdAt: FieldValue.serverTimestamp(),
    });

    batch.update(circleRef, {
      postCount: FieldValue.increment(1),
    });

    await batch.commit();

    return { success: true, momentId: momentRef.id };
  });
