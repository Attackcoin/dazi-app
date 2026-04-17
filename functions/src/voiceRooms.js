/**
 * 语音房模块（T5-20）
 *
 * Geneva 模式的轻量语音聊天室 — 用户可以创建/加入语音房，
 * 实时语音由前端 Agora SDK 处理，后端管理房间生命周期。
 *
 * 数据模型：
 *   voiceRooms/{roomId}
 *     title, topic, category, hostId, hostName, hostAvatar,
 *     maxParticipants, participants[], speakerIds[],
 *     isLive, createdAt, endedAt
 *
 * 包含：
 * - createVoiceRoom   创建语音房 (onCall)
 * - joinVoiceRoom     加入语音房 (onCall)
 * - leaveVoiceRoom    离开语音房 (onCall)
 * - endVoiceRoom      结束语音房 (onCall, 仅主持人)
 * - listVoiceRooms    获取进行中的语音房列表 (onCall)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

const MAX_TITLE = 50;
const MAX_TOPIC = 200;
const MAX_PARTICIPANTS = 20;
const DEFAULT_MAX = 8;

// ─────────────────────────────────────────────────────
// 创建语音房
// ─────────────────────────────────────────────────────
exports.createVoiceRoom = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { title, topic, category, maxParticipants } = data;

    if (!title || title.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', '房间标题不能为空');
    }
    if (title.length > MAX_TITLE) {
      throw new functions.https.HttpsError('invalid-argument', `标题不能超过${MAX_TITLE}字`);
    }
    if (topic && topic.length > MAX_TOPIC) {
      throw new functions.https.HttpsError('invalid-argument', `话题不能超过${MAX_TOPIC}字`);
    }

    const maxP = Math.min(Math.max(maxParticipants || DEFAULT_MAX, 2), MAX_PARTICIPANTS);

    // 获取主持人信息用于 denorm
    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.exists ? userDoc.data() : {};

    const roomRef = db.collection('voiceRooms').doc();

    await roomRef.set({
      title: title.trim(),
      topic: (topic || '').trim(),
      category: category || '',
      hostId: uid,
      hostName: user.name || '',
      hostAvatar: user.avatar || '',
      maxParticipants: maxP,
      participants: [uid],
      speakerIds: [uid], // 主持人默认是 speaker
      participantCount: 1,
      isLive: true,
      createdAt: FieldValue.serverTimestamp(),
      endedAt: null,
    });

    return { success: true, roomId: roomRef.id };
  });

// ─────────────────────────────────────────────────────
// 加入语音房
// ─────────────────────────────────────────────────────
exports.joinVoiceRoom = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { roomId } = data;

    if (!roomId) {
      throw new functions.https.HttpsError('invalid-argument', 'roomId 不能为空');
    }

    const roomRef = db.collection('voiceRooms').doc(roomId);
    const roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      throw new functions.https.HttpsError('not-found', '语音房不存在');
    }

    const room = roomDoc.data();

    if (!room.isLive) {
      throw new functions.https.HttpsError('failed-precondition', '语音房已结束');
    }

    if (room.participants.includes(uid)) {
      return { success: true, alreadyJoined: true };
    }

    if (room.participants.length >= room.maxParticipants) {
      throw new functions.https.HttpsError('resource-exhausted', '语音房已满');
    }

    await roomRef.update({
      participants: FieldValue.arrayUnion(uid),
      participantCount: FieldValue.increment(1),
    });

    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 离开语音房
// ─────────────────────────────────────────────────────
exports.leaveVoiceRoom = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { roomId } = data;

    if (!roomId) {
      throw new functions.https.HttpsError('invalid-argument', 'roomId 不能为空');
    }

    const roomRef = db.collection('voiceRooms').doc(roomId);
    const roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      throw new functions.https.HttpsError('not-found', '语音房不存在');
    }

    const room = roomDoc.data();

    if (!room.participants.includes(uid)) {
      return { success: true, notInRoom: true };
    }

    // 如果主持人离开 → 自动结束房间
    if (room.hostId === uid) {
      await roomRef.update({
        isLive: false,
        endedAt: FieldValue.serverTimestamp(),
        participants: [],
        speakerIds: [],
        participantCount: 0,
      });
      return { success: true, roomEnded: true };
    }

    await roomRef.update({
      participants: FieldValue.arrayRemove(uid),
      speakerIds: FieldValue.arrayRemove(uid),
      participantCount: FieldValue.increment(-1),
    });

    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 结束语音房（仅主持人）
// ─────────────────────────────────────────────────────
exports.endVoiceRoom = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { roomId } = data;

    if (!roomId) {
      throw new functions.https.HttpsError('invalid-argument', 'roomId 不能为空');
    }

    const roomRef = db.collection('voiceRooms').doc(roomId);
    const roomDoc = await roomRef.get();

    if (!roomDoc.exists) {
      throw new functions.https.HttpsError('not-found', '语音房不存在');
    }

    const room = roomDoc.data();

    if (room.hostId !== uid) {
      throw new functions.https.HttpsError('permission-denied', '只有主持人可以结束语音房');
    }

    if (!room.isLive) {
      return { success: true, alreadyEnded: true };
    }

    await roomRef.update({
      isLive: false,
      endedAt: FieldValue.serverTimestamp(),
      participants: [],
      speakerIds: [],
      participantCount: 0,
    });

    return { success: true };
  });

// ─────────────────────────────────────────────────────
// 获取进行中的语音房列表
// ─────────────────────────────────────────────────────
exports.listVoiceRooms = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const { category, limit: queryLimit } = data;
    const limitN = Math.min(queryLimit || 20, 50);

    let query = db.collection('voiceRooms')
      .where('isLive', '==', true)
      .orderBy('participantCount', 'desc')
      .limit(limitN);

    if (category) {
      query = db.collection('voiceRooms')
        .where('isLive', '==', true)
        .where('category', '==', category)
        .orderBy('participantCount', 'desc')
        .limit(limitN);
    }

    const snap = await query.get();

    const rooms = snap.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    }));

    return { rooms };
  });
