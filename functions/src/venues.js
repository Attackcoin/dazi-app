/**
 * B2B 活动场地合作模块（T5-18）
 *
 * 咖啡厅/健身房/餐厅等线下场地与平台合作引流，用户到场消费产生佣金。
 *
 * 数据模型：
 *   venues/{venueId}
 *     name, description, category, address, lat, lng,
 *     coverImage, images, contactName, contactPhone,
 *     commissionRate, isActive, perks,
 *     totalCheckins, totalRevenue, createdAt
 *
 *   venues/{venueId}/checkins/{checkinId}
 *     uid, matchId, postId, checkedInAt, commissionAmount, settled
 *
 * 包含：
 * - registerVenue        场地入驻申请 (onCall)
 * - listNearbyVenues     获取附近合作场地 (onCall)
 * - venueCheckin         用户在合作场地签到 (onCall)
 * - settleVenueCommission  结算佣金（定时） (scheduled)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

const MAX_VENUE_NAME = 50;
const MAX_VENUE_DESC = 1000;
const DEFAULT_COMMISSION_RATE = 0.10; // 默认佣金率 10%

// ─────────────────────────────────────────────────────
// 场地入驻申请
// ─────────────────────────────────────────────────────
exports.registerVenue = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { name, description, category, address, lat, lng, contactName, contactPhone, perks } = data;

    if (!name || name.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', '场地名称不能为空');
    }
    if (name.length > MAX_VENUE_NAME) {
      throw new functions.https.HttpsError('invalid-argument', `名称不能超过${MAX_VENUE_NAME}字`);
    }
    if (description && description.length > MAX_VENUE_DESC) {
      throw new functions.https.HttpsError('invalid-argument', `描述不能超过${MAX_VENUE_DESC}字`);
    }
    if (!address || address.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', '地址不能为空');
    }

    const venueRef = db.collection('venues').doc();

    await venueRef.set({
      name: name.trim(),
      description: (description || '').trim(),
      category: category || '咖啡厅',
      address: address.trim(),
      lat: lat || 0,
      lng: lng || 0,
      coverImage: '',
      images: [],
      contactName: (contactName || '').trim(),
      contactPhone: (contactPhone || '').trim(),
      commissionRate: DEFAULT_COMMISSION_RATE,
      isActive: false, // 需要审核后激活
      perks: Array.isArray(perks) ? perks.slice(0, 5) : [],
      ownerId: uid,
      totalCheckins: 0,
      totalRevenue: 0,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { success: true, venueId: venueRef.id, status: 'pending_review' };
  });

// ─────────────────────────────────────────────────────
// 获取附近合作场地（简化版：按城市筛选）
// ─────────────────────────────────────────────────────
exports.listNearbyVenues = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const { category, limit: queryLimit } = data;
    const limitN = Math.min(queryLimit || 20, 50);

    let query = db.collection('venues')
      .where('isActive', '==', true)
      .orderBy('totalCheckins', 'desc')
      .limit(limitN);

    if (category) {
      query = db.collection('venues')
        .where('isActive', '==', true)
        .where('category', '==', category)
        .orderBy('totalCheckins', 'desc')
        .limit(limitN);
    }

    const snap = await query.get();

    const venues = snap.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || null,
    }));

    return { venues };
  });

// ─────────────────────────────────────────────────────
// 用户在合作场地签到（活动到场确认）
// ─────────────────────────────────────────────────────
exports.venueCheckin = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { venueId, matchId, postId } = data;

    if (!venueId) {
      throw new functions.https.HttpsError('invalid-argument', 'venueId 不能为空');
    }

    const venueRef = db.collection('venues').doc(venueId);
    const venueDoc = await venueRef.get();

    if (!venueDoc.exists) {
      throw new functions.https.HttpsError('not-found', '场地不存在');
    }

    const venue = venueDoc.data();
    if (!venue.isActive) {
      throw new functions.https.HttpsError('failed-precondition', '场地暂未开放');
    }

    // 幂等：同一用户 + 同一活动在同一场地只能签到一次
    const checkinId = `${venueId}_${uid}_${matchId || 'walk_in'}`;
    const existingCheckin = await venueRef.collection('checkins').doc(checkinId).get();
    if (existingCheckin.exists) {
      return { success: true, alreadyCheckedIn: true };
    }

    const commissionAmount = venue.commissionRate || DEFAULT_COMMISSION_RATE;

    const batch = db.batch();

    batch.set(venueRef.collection('checkins').doc(checkinId), {
      uid,
      matchId: matchId || '',
      postId: postId || '',
      commissionAmount,
      settled: false,
      checkedInAt: FieldValue.serverTimestamp(),
    });

    batch.update(venueRef, {
      totalCheckins: FieldValue.increment(1),
    });

    await batch.commit();

    return {
      success: true,
      perks: venue.perks || [],
    };
  });

// ─────────────────────────────────────────────────────
// 定时结算佣金（每天凌晨 2 点）
// ─────────────────────────────────────────────────────
exports.settleVenueCommission = functions
  .region('asia-southeast1')
  .pubsub.schedule('every day 02:00')
  .timeZone('Asia/Shanghai')
  .onRun(async () => {
    // 找出所有未结算的签到记录
    const venues = await db.collection('venues')
      .where('isActive', '==', true)
      .get();

    let totalSettled = 0;

    for (const venueDoc of venues.docs) {
      const unsettled = await venueDoc.ref.collection('checkins')
        .where('settled', '==', false)
        .limit(100)
        .get();

      if (unsettled.empty) continue;

      const batch = db.batch();
      let venueRevenue = 0;

      for (const checkin of unsettled.docs) {
        batch.update(checkin.ref, {
          settled: true,
          settledAt: FieldValue.serverTimestamp(),
        });
        venueRevenue += checkin.data().commissionAmount || 0;
        totalSettled++;
      }

      batch.update(venueDoc.ref, {
        totalRevenue: FieldValue.increment(venueRevenue),
      });

      await batch.commit();
    }

    console.log(`场地佣金结算：${totalSettled} 笔`);
  });
