/**
 * 内容审核模块
 * 使用 OpenAI Moderation API（omni-moderation-latest，支持中英文 + 图片）
 *
 * 包含：
 * - onPostCreated        Firestore 触发器：帖子创建时自动审核
 * - _moderateText        内部函数：文本审核
 * - _moderateImage       内部函数：图片 URL 审核
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

const OPENAI_MODERATION_URL = 'https://api.openai.com/v1/moderations';

function getOpenAIKey() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) throw new Error('OPENAI_API_KEY not configured');
  return key;
}

// ─────────────────────────────────────────────────────
// 内部：文本审核
// 返回 { flagged: bool, categories: string[] }
// ─────────────────────────────────────────────────────
async function _moderateText(text) {
  if (!text || text.trim().length === 0) return { flagged: false, categories: [] };

  const apiKey = getOpenAIKey();
  const resp = await axios.post(
    OPENAI_MODERATION_URL,
    { input: text, model: 'omni-moderation-latest' },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 10000 },
  );

  const result = resp.data.results[0];
  if (!result.flagged) return { flagged: false, categories: [] };

  const flaggedCategories = Object.entries(result.categories)
    .filter(([, v]) => v === true)
    .map(([k]) => k);

  return { flagged: true, categories: flaggedCategories };
}

// ─────────────────────────────────────────────────────
// 内部：图片 URL 审核
// ─────────────────────────────────────────────────────
async function _moderateImage(imageUrl) {
  if (!imageUrl) return { flagged: false, categories: [] };

  const apiKey = getOpenAIKey();
  const resp = await axios.post(
    OPENAI_MODERATION_URL,
    {
      model: 'omni-moderation-latest',
      input: [{ type: 'image_url', image_url: { url: imageUrl } }],
    },
    { headers: { Authorization: `Bearer ${apiKey}` }, timeout: 15000 },
  );

  const result = resp.data.results[0];
  if (!result.flagged) return { flagged: false, categories: [] };

  const flaggedCategories = Object.entries(result.categories)
    .filter(([, v]) => v === true)
    .map(([k]) => k);

  return { flagged: true, categories: flaggedCategories };
}

// ─────────────────────────────────────────────────────
// Firestore 触发器：帖子创建时自动审核
// ─────────────────────────────────────────────────────
exports.onPostCreatedModeration = functions
  .region('asia-southeast1')
  .firestore.document('posts/{postId}')
  .onCreate(async (snap) => {
    const post = snap.data();
    const postId = snap.id;

    try {
      // 合并标题和描述审核
      const textToCheck = [post.title, post.description].filter(Boolean).join('\n');
      const textResult = await _moderateText(textToCheck);

      // 审核第一张图片（如有）
      let imageResult = { flagged: false, categories: [] };
      if (Array.isArray(post.images) && post.images.length > 0) {
        try {
          imageResult = await _moderateImage(post.images[0]);
        } catch (imgErr) {
          console.warn(`图片审核失败 postId=${postId}:`, imgErr.message);
        }
      }

      const flagged = textResult.flagged || imageResult.flagged;
      const allCategories = [
        ...textResult.categories,
        ...imageResult.categories,
      ];

      await snap.ref.update({
        moderationStatus: flagged ? 'rejected' : 'approved',
        moderationCategories: allCategories,
        moderatedAt: FieldValue.serverTimestamp(),
      });

      if (flagged) {
        console.log(
          `帖子审核不通过 postId=${postId} categories=${allCategories.join(',')}`,
        );
      }
    } catch (err) {
      console.error(`帖子审核失败 postId=${postId}:`, err.message);
      // 审核失败时默认放行（避免 API 故障阻塞发帖）
      await snap.ref.update({
        moderationStatus: 'approved',
        moderationError: err.message,
        moderatedAt: FieldValue.serverTimestamp(),
      });
    }
  });

// ─────────────────────────────────────────────────────
// Firestore 触发器：帖子更新时重新审核标题/描述
// ─────────────────────────────────────────────────────
exports.onPostUpdatedModeration = functions
  .region('asia-southeast1')
  .firestore.document('posts/{postId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // 只在标题或描述变更时重新审核
    if (before.title === after.title && before.description === after.description) {
      return;
    }

    // 避免审核结果写入触发无限循环
    if (before.moderationStatus !== after.moderationStatus) return;

    const postId = change.after.id;

    try {
      const textToCheck = [after.title, after.description].filter(Boolean).join('\n');
      const textResult = await _moderateText(textToCheck);

      await change.after.ref.update({
        moderationStatus: textResult.flagged ? 'rejected' : 'approved',
        moderationCategories: textResult.categories,
        moderatedAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error(`帖子更新审核失败 postId=${postId}:`, err.message);
    }
  });

exports._moderateText = _moderateText;
exports._moderateImage = _moderateImage;
