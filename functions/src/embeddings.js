/**
 * Embedding 智能推荐模块
 * 使用 OpenAI text-embedding-3-small 生成向量
 * 配合 Firestore Vector Search (findNearest) 做个性化 feed 召回
 *
 * 包含：
 * - onPostCreatedEmbedding    帖子创建时生成 embedding
 * - onUserProfileUpdated      用户资料更新时生成 embedding
 * - getRecommendedPosts       获取个性化推荐帖子 (onCall)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

const OPENAI_EMBEDDING_URL = 'https://api.openai.com/v1/embeddings';
const EMBEDDING_MODEL = 'text-embedding-3-small';
const EMBEDDING_DIMENSIONS = 256; // 降维减少存储成本（原1536维）

function getOpenAIKey() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error('OPENAI_API_KEY not configured');
  return key;
}

// ─────────────────────────────────────────────────────
// 内部：生成文本 embedding
// ─────────────────────────────────────────────────────
async function _generateEmbedding(text) {
  if (!text || text.trim().length === 0) return null;

  const apiKey = getOpenAIKey();
  const resp = await axios.post(
    OPENAI_EMBEDDING_URL,
    {
      input: text.slice(0, 8000), // 限制输入长度
      model: EMBEDDING_MODEL,
      dimensions: EMBEDDING_DIMENSIONS,
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 10000 },
  );

  return resp.data.data[0].embedding;
}

// ─────────────────────────────────────────────────────
// 将帖子信息拼接为可嵌入的文本
// ─────────────────────────────────────────────────────
function _postToText(post) {
  const parts = [
    post.title,
    post.description,
    post.category,
    ...(Array.isArray(post.tags) ? post.tags : []),
    post.location?.name,
  ].filter(Boolean);
  return parts.join(' ');
}

// ─────────────────────────────────────────────────────
// 将用户信息拼接为可嵌入的文本
// ─────────────────────────────────────────────────────
function _userToText(user) {
  const parts = [
    user.name,
    user.bio,
    ...(Array.isArray(user.tags) ? user.tags : []),
    user.city,
  ].filter(Boolean);
  return parts.join(' ');
}

// ─────────────────────────────────────────────────────
// Firestore 触发器：帖子创建时生成 embedding
// ─────────────────────────────────────────────────────
exports.onPostCreatedEmbedding = functions
  .region('asia-southeast1')
  .firestore.document('posts/{postId}')
  .onCreate(async (snap) => {
    const post = snap.data();
    const postId = snap.id;

    try {
      const text = _postToText(post);
      const embedding = await _generateEmbedding(text);

      if (embedding) {
        await snap.ref.update({
          embedding: FieldValue.vector(embedding),
          embeddingGeneratedAt: FieldValue.serverTimestamp(),
        });
      }
    } catch (err) {
      console.error(`帖子 embedding 生成失败 postId=${postId}:`, err.message);
    }
  });

// ─────────────────────────────────────────────────────
// Firestore 触发器：用户资料更新时重新生成 embedding
// 只在 bio 或 tags 变更时触发
// ─────────────────────────────────────────────────────
exports.onUserProfileUpdated = functions
  .region('asia-southeast1')
  .firestore.document('users/{userId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // 只在 bio/tags/name 变更时重新生成
    const bioChanged = before.bio !== after.bio;
    const tagsChanged = JSON.stringify(before.tags) !== JSON.stringify(after.tags);
    const nameChanged = before.name !== after.name;

    if (!bioChanged && !tagsChanged && !nameChanged) return;

    // 避免 embedding 写入触发无限循环
    if (before.embeddingGeneratedAt !== after.embeddingGeneratedAt) return;

    const userId = change.after.id;

    try {
      const text = _userToText(after);
      const embedding = await _generateEmbedding(text);

      if (embedding) {
        await change.after.ref.update({
          embedding: FieldValue.vector(embedding),
          embeddingGeneratedAt: FieldValue.serverTimestamp(),
        });
      }
    } catch (err) {
      console.error(`用户 embedding 生成失败 userId=${userId}:`, err.message);
    }
  });

// ─────────────────────────────────────────────────────
// 获取个性化推荐帖子 (onCall)
// 用用户 embedding 做 Firestore Vector Search
// ─────────────────────────────────────────────────────
exports.getRecommendedPosts = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;
    const limit = Math.min(data.limit || 20, 50);

    // 获取用户 embedding
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', '用户不存在');
    }

    const user = userDoc.data();
    let queryVector = user.embedding;

    // 如果用户还没有 embedding，即时生成
    if (!queryVector) {
      const text = _userToText(user);
      queryVector = await _generateEmbedding(text);
      if (queryVector) {
        // 顺便存上
        await userDoc.ref.update({
          embedding: FieldValue.vector(queryVector),
          embeddingGeneratedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    if (!queryVector) {
      // 没有足够资料生成 embedding，返回空
      return { posts: [] };
    }

    // Firestore Vector Search — findNearest
    const postsRef = db.collection('posts')
      .where('status', '==', 'open');

    const vectorQuery = postsRef.findNearest({
      vectorField: 'embedding',
      queryVector: FieldValue.vector(queryVector),
      limit,
      distanceMeasure: 'COSINE',
    });

    const snap = await vectorQuery.get();

    const posts = snap.docs
      .filter(doc => doc.data().userId !== uid) // 排除自己的帖子
      .map(doc => ({
        id: doc.id,
        title: doc.data().title,
        category: doc.data().category,
        publisherName: doc.data().publisherName,
      }));

    return { posts };
  });

exports._generateEmbedding = _generateEmbedding;
exports._postToText = _postToText;
exports._userToText = _userToText;
