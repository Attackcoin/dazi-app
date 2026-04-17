/**
 * 行为信任分模块（T5-17）
 *
 * 基于用户的历史行为（签到、爽约、评价、活动次数）计算综合信任分。
 * 信任分影响：
 *   - 低分（<40）限制发帖和申请
 *   - 中分（40-70）正常使用
 *   - 高分（>70）获得"靠谱"标签 + 优先展示
 *
 * 计算公式：
 *   baseScore = 60（新用户起始）
 *   + totalMeetups × 2（每次完成活动 +2，上限 +30）
 *   + (avgRating - 3) × 10（评分高于3分加分，低于3分扣分）
 *   - ghostCount × 15（每次爽约 -15）
 *   + verifiedBonus（身份验证 +5）
 *   结果裁剪到 [0, 100]
 *
 * 数据存储：
 *   users/{uid}.trustScore    当前信任分 (0-100)
 *   users/{uid}.trustLevel    信任等级 ('new' | 'normal' | 'trusted' | 'restricted')
 *
 * 包含：
 * - recalcTrustScore     按需重算信任分 (onCall)
 * - onReviewWritten      评价写入后触发重算 (Firestore trigger)
 * - onMatchCompleted     活动完成后触发重算 (Firestore trigger)
 * - getTrustInfo         获取信任分详情 (onCall)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

// ─── 信任分计算参数 ─────────────────────────────────
const BASE_SCORE = 60;
const MEETUP_BONUS = 2;        // 每次完成活动 +2
const MAX_MEETUP_BONUS = 30;   // 活动加分上限
const GHOST_PENALTY = 15;      // 每次爽约 -15
const RATING_WEIGHT = 10;      // (avgRating - 3) × 10
const VERIFIED_BONUS = 5;      // 身份验证加分
const MIN_SCORE = 0;
const MAX_SCORE = 100;

// 信任等级阈值
const TRUST_LEVELS = {
  restricted: 40,   // < 40 受限
  normal: 70,       // 40-70 正常
  trusted: 70,      // >= 70 信任
};

/**
 * 计算信任分 — 纯函数，便于测试。
 */
function _calculateTrustScore(user) {
  const totalMeetups = user.totalMeetups || 0;
  const ghostCount = user.ghostCount || 0;
  const ratingSum = user.ratingSum || 0;
  const ratingCount = user.ratingCount || 0;
  const verificationLevel = user.verificationLevel || 1;

  // 活动完成加分（上限 30）
  const meetupBonus = Math.min(totalMeetups * MEETUP_BONUS, MAX_MEETUP_BONUS);

  // 评分加减分（有评价才计算）
  let ratingBonus = 0;
  if (ratingCount > 0) {
    const avgRating = ratingSum / ratingCount;
    ratingBonus = (avgRating - 3) * RATING_WEIGHT;
  }

  // 爽约扣分
  const ghostPenalty = ghostCount * GHOST_PENALTY;

  // 身份验证加分
  const verifiedBonus = verificationLevel >= 2 ? VERIFIED_BONUS : 0;

  // 汇总
  const raw = BASE_SCORE + meetupBonus + ratingBonus - ghostPenalty + verifiedBonus;

  return Math.max(MIN_SCORE, Math.min(MAX_SCORE, Math.round(raw)));
}

/**
 * 根据分数判定信任等级。
 */
function _getTrustLevel(score) {
  if (score < TRUST_LEVELS.restricted) return 'restricted';
  if (score >= TRUST_LEVELS.trusted) return 'trusted';
  return 'normal';
}

/**
 * 更新用户信任分（内部共用逻辑）。
 */
async function _updateUserTrustScore(uid) {
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) return null;

  const user = userDoc.data();
  const score = _calculateTrustScore(user);
  const level = _getTrustLevel(score);

  await db.collection('users').doc(uid).update({
    trustScore: score,
    trustLevel: level,
    trustUpdatedAt: FieldValue.serverTimestamp(),
  });

  return { uid, score, level };
}

// ─────────────────────────────────────────────────────
// 按需重算信任分（用户主动或管理员调用）
// ─────────────────────────────────────────────────────
exports.recalcTrustScore = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const result = await _updateUserTrustScore(uid);

    if (!result) {
      throw new functions.https.HttpsError('not-found', '用户不存在');
    }

    return {
      success: true,
      score: result.score,
      level: result.level,
    };
  });

// ─────────────────────────────────────────────────────
// 评价写入后触发重算被评价者的信任分
// ─────────────────────────────────────────────────────
exports.onReviewWrittenTrust = functions
  .region('asia-southeast1')
  .firestore.document('reviews/{reviewId}')
  .onCreate(async (snap) => {
    const review = snap.data();
    const toUser = review.toUser;
    if (!toUser) return;

    await _updateUserTrustScore(toUser);
  });

// ─────────────────────────────────────────────────────
// 活动完成后触发重算所有参与者的信任分
// ─────────────────────────────────────────────────────
exports.onMatchCompletedTrust = functions
  .region('asia-southeast1')
  .firestore.document('matches/{matchId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // 只在状态变为 completed/ghosted/ghosted_all 时触发
    const triggerStatuses = ['completed', 'ghosted', 'ghosted_all'];
    if (triggerStatuses.includes(before.status) || !triggerStatuses.includes(after.status)) {
      return;
    }

    const participants = after.participants || [];
    await Promise.all(participants.map(uid => _updateUserTrustScore(uid)));
  });

// ─────────────────────────────────────────────────────
// 获取信任分详情（查看自己的信任分组成）
// ─────────────────────────────────────────────────────
exports.getTrustInfo = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', '用户不存在');
    }

    const user = userDoc.data();
    const totalMeetups = user.totalMeetups || 0;
    const ghostCount = user.ghostCount || 0;
    const ratingSum = user.ratingSum || 0;
    const ratingCount = user.ratingCount || 0;
    const verificationLevel = user.verificationLevel || 1;
    const avgRating = ratingCount > 0 ? ratingSum / ratingCount : 0;

    const meetupBonus = Math.min(totalMeetups * MEETUP_BONUS, MAX_MEETUP_BONUS);
    const ratingBonus = ratingCount > 0 ? (avgRating - 3) * RATING_WEIGHT : 0;
    const ghostPenalty = ghostCount * GHOST_PENALTY;
    const verifiedBonus = verificationLevel >= 2 ? VERIFIED_BONUS : 0;

    const score = _calculateTrustScore(user);
    const level = _getTrustLevel(score);

    return {
      score,
      level,
      breakdown: {
        baseScore: BASE_SCORE,
        meetupBonus: Math.round(meetupBonus),
        ratingBonus: Math.round(ratingBonus * 10) / 10,
        ghostPenalty: Math.round(ghostPenalty),
        verifiedBonus,
      },
      stats: {
        totalMeetups,
        ghostCount,
        avgRating: Math.round(avgRating * 10) / 10,
        ratingCount,
        verificationLevel,
      },
    };
  });

// 导出内部函数供测试
exports._calculateTrustScore = _calculateTrustScore;
exports._getTrustLevel = _getTrustLevel;
