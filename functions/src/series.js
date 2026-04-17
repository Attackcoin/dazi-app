/**
 * 系列活动模块
 * 处理：批量创建重复活动组（如每周跑步、每两周读书会）
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = admin.firestore();

// 合法的重复频率
const VALID_RECURRENCES = ['weekly', 'biweekly'];
// 重复周期映射（天数）
const RECURRENCE_DAYS = { weekly: 7, biweekly: 14 };
// totalWeeks 范围
const MIN_WEEKS = 2;
const MAX_WEEKS = 8;

// ─────────────────────────────────────────────────────
// 创建系列活动（批量生成 N 个 post 文档）
// ─────────────────────────────────────────────────────
exports.createSeriesPosts = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    // 1. 认证检查
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const { templatePost, recurrence, totalWeeks } = data;

    // 2. 参数验证
    if (!templatePost || typeof templatePost !== 'object') {
      throw new functions.https.HttpsError('invalid-argument', '缺少 templatePost');
    }
    if (!VALID_RECURRENCES.includes(recurrence)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `recurrence 必须是 ${VALID_RECURRENCES.join(' 或 ')}`
      );
    }
    if (
      !Number.isInteger(totalWeeks) ||
      totalWeeks < MIN_WEEKS ||
      totalWeeks > MAX_WEEKS
    ) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `totalWeeks 必须是 ${MIN_WEEKS}-${MAX_WEEKS} 的整数`
      );
    }
    if (!templatePost.title || typeof templatePost.title !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', '缺少 title');
    }
    if (!templatePost.time) {
      throw new functions.https.HttpsError('invalid-argument', '缺少 time');
    }

    // 3. 生成 seriesId
    const seriesRef = db.collection('posts').doc();
    const seriesId = seriesRef.id;

    // 4. 获取用户信息（publisherName, publisherAvatar）
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', '用户不存在');
    }
    const user = userDoc.data();
    const publisherName = user.name || '';
    const publisherAvatar = user.avatar || '';

    // 5. 解析基准时间
    const baseTime = new Date(templatePost.time);
    if (isNaN(baseTime.getTime())) {
      throw new functions.https.HttpsError('invalid-argument', 'time 格式无效');
    }
    const intervalDays = RECURRENCE_DAYS[recurrence];

    // 6. 用 batch write 创建 totalWeeks 个 post 文档
    const batch = db.batch();
    const postIds = [];

    for (let week = 1; week <= totalWeeks; week++) {
      const postRef = db.collection('posts').doc();
      postIds.push(postRef.id);

      // 计算该周的活动时间
      const postTime = new Date(
        baseTime.getTime() + (week - 1) * intervalDays * 24 * 60 * 60 * 1000
      );

      // 标题格式：原标题（第N/M周）
      const title = `${templatePost.title}（第${week}/${totalWeeks}周）`;

      const postData = {
        userId: uid,
        title,
        description: templatePost.description || '',
        category: templatePost.category || '',
        time: Timestamp.fromDate(postTime),
        location: templatePost.location || {},
        totalSlots: templatePost.totalSlots || 2,
        minSlots: templatePost.minSlots || 1,
        gender: templatePost.gender || 'any',
        genderQuota: templatePost.genderQuota || null,
        costType: templatePost.costType || 'free',
        depositAmount: templatePost.depositAmount || 0,
        images: templatePost.images || [],
        tags: templatePost.tags || [],
        isSocialAnxietyFriendly:
          templatePost.isSocialAnxietyFriendly || false,
        isInstant: templatePost.isInstant || false,
        publisherName,
        publisherAvatar,
        // 系列活动字段
        seriesId,
        recurrence,
        seriesWeek: week,
        seriesTotalWeeks: totalWeeks,
        // 标准初始值
        status: 'open',
        waitlist: [],
        acceptedGender: { male: 0, female: 0 },
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      batch.set(postRef, postData);
    }

    await batch.commit();

    // 7. 返回结果
    return { seriesId, postIds };
  });
