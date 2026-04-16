/**
 * Algolia 搜索同步
 *
 * 监听 Firestore posts 集合变化，自动同步到 Algolia 索引。
 * 用于支持中文全文搜索（Firestore 原生不支持）。
 *
 * 替代方案：使用官方 Firebase Extension「Search with Algolia」
 * 本文件是自建版本，便于自定义字段映射和过滤逻辑。
 *
 * 部署前需设置环境变量：
 *   firebase functions:config:set algolia.app_id="XXX" algolia.admin_key="YYY"
 * 或在 functions/.env 中填写 ALGOLIA_APP_ID / ALGOLIA_ADMIN_KEY
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');

const ALGOLIA_APP_ID = process.env.ALGOLIA_APP_ID || '';
const ALGOLIA_ADMIN_KEY = process.env.ALGOLIA_ADMIN_KEY || '';
const INDEX_NAME = 'posts';

// 懒加载 algoliasearch，避免未配置密钥时函数冷启动失败
let cachedIndex = null;
function getIndex() {
  if (cachedIndex) return cachedIndex;
  if (!ALGOLIA_APP_ID || !ALGOLIA_ADMIN_KEY) {
    logger.warn('Algolia 密钥未配置，跳过同步');
    return null;
  }
  const algoliasearch = require('algoliasearch');
  const client = algoliasearch(ALGOLIA_APP_ID, ALGOLIA_ADMIN_KEY);
  cachedIndex = client.initIndex(INDEX_NAME);
  return cachedIndex;
}

/**
 * 把 Firestore post 文档转换成 Algolia record
 * 只同步搜索需要的字段，避免把完整文档扔到第三方。
 */
function toAlgoliaRecord(postId, data) {
  return {
    objectID: postId,
    title: data.title || '',
    description: data.description || '',
    category: data.category || '',
    locationName: (data.location && data.location.name) || '',
    city: data.location && data.location.city ? data.location.city : data.city || '',
    _geoloc: data.location && data.location.lat && data.location.lng
      ? { lat: data.location.lat, lng: data.location.lng }
      : undefined,
    time: data.time && data.time.toMillis ? data.time.toMillis() : null,
    costType: data.costType || '',
    isSocialAnxietyFriendly: !!data.isSocialAnxietyFriendly,
    isInstant: !!data.isInstant,
    status: data.status || 'open',
    totalSlots: data.totalSlots || 0,
    publisherName: data.publisherName || '',
    createdAt: data.createdAt && data.createdAt.toMillis ? data.createdAt.toMillis() : Date.now(),
  };
}

exports.syncPostToAlgolia = onDocumentWritten(
  {
    document: 'posts/{postId}',
    region: 'asia-southeast1',
  },
  async (event) => {
    const index = getIndex();
    if (!index) return;

    const postId = event.params.postId;
    const after = event.data && event.data.after && event.data.after.exists ? event.data.after.data() : null;
    const before = event.data && event.data.before && event.data.before.exists ? event.data.before.data() : null;

    try {
      // 删除
      if (!after) {
        await index.deleteObject(postId);
        logger.info(`Algolia: 已删除 ${postId}`);
        return;
      }

      // 已过期或已结束的帖子从索引移除，节省搜索配额
      if (after.status && ['done', 'cancelled', 'expired'].includes(after.status)) {
        await index.deleteObject(postId);
        logger.info(`Algolia: 已移除非活跃帖子 ${postId} (status=${after.status})`);
        return;
      }

      // 新增或更新
      const record = toAlgoliaRecord(postId, after);
      await index.saveObject(record);
      logger.info(`Algolia: 已同步 ${postId}`);
    } catch (err) {
      logger.error(`Algolia 同步失败 ${postId}:`, err);
    }
  }
);

/**
 * 一次性全量回填（手动触发 HTTP 函数）
 * 用于首次上线或 Algolia 索引丢失后恢复数据。
 * 调用方式（需 Firebase Auth admin token）:
 *   curl -X POST https://REGION-PROJECT.cloudfunctions.net/algoliaBackfill
 */
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

exports.algoliaBackfill = onRequest(
  { region: 'asia-southeast1', cors: false },
  async (req, res) => {
    // 简单保护：必须带 X-Admin-Secret header
    const secret = req.get('X-Admin-Secret');
    if (!secret || secret !== process.env.ADMIN_SECRET) {
      res.status(401).send('Unauthorized');
      return;
    }

    const index = getIndex();
    if (!index) {
      res.status(500).send('Algolia not configured');
      return;
    }

    try {
      const snapshot = await admin.firestore()
        .collection('posts')
        .where('status', '==', 'open')
        .get();

      const records = snapshot.docs.map((d) => toAlgoliaRecord(d.id, d.data()));
      await index.saveObjects(records);

      logger.info(`Algolia 回填完成：${records.length} 条`);
      res.json({ ok: true, count: records.length });
    } catch (err) {
      logger.error('Algolia 回填失败:', err);
      res.status(500).json({ error: err.message });
    }
  }
);
