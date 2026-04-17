/**
 * 身份验证模块
 * 处理：Stripe Identity 证件验证（verificationLevel 1→2）
 *
 * 环境变量：
 *   STRIPE_SECRET_KEY     — Stripe API 密钥
 *   STRIPE_WEBHOOK_SECRET — Stripe webhook 签名密钥
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

// Stripe SDK — 延迟初始化，仅在实际调用时实例化
let _stripe = null;
function getStripe() {
  if (_stripe) return _stripe;
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'STRIPE_SECRET_KEY 未配置'
    );
  }
  const Stripe = require('stripe');
  _stripe = new Stripe(key);
  return _stripe;
}

// ─────────────────────────────────────────────────────
// 发起身份验证（创建 Stripe VerificationSession）
// ─────────────────────────────────────────────────────
exports.startIdentityVerification = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const uid = context.auth.uid;

    // 查询用户当前 verificationLevel
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', '用户不存在');
    }

    const userData = userDoc.data();
    if ((userData.verificationLevel || 1) >= 2) {
      throw new functions.https.HttpsError(
        'already-exists',
        '已完成证件验证，无需重复'
      );
    }

    const stripe = getStripe();
    const session = await stripe.identity.verificationSessions.create({
      type: 'document',
      metadata: { uid },
    });

    return {
      clientSecret: session.client_secret,
      verificationSessionId: session.id,
    };
  });

// ─────────────────────────────────────────────────────
// Stripe Identity Webhook（接收验证结果）
// ─────────────────────────────────────────────────────
exports.stripeIdentityWebhook = functions
  .region('asia-southeast1')
  .https.onRequest(async (req, res) => {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!webhookSecret) {
      console.error('STRIPE_WEBHOOK_SECRET 未配置');
      res.status(500).send('Webhook secret not configured');
      return;
    }

    // 验证 webhook 签名
    let event;
    try {
      const stripe = getStripe();
      const sig = req.headers['stripe-signature'];
      event = stripe.webhooks.constructEvent(
        req.rawBody || req.body,
        sig,
        webhookSecret
      );
    } catch (err) {
      console.error('Webhook 签名验证失败:', err.message);
      res.status(400).send(`Webhook signature verification failed`);
      return;
    }

    // 处理事件
    if (event.type === 'identity.verification_session.verified') {
      const session = event.data.object;
      const uid = session.metadata && session.metadata.uid;
      if (!uid) {
        console.error('Webhook session 缺少 uid metadata');
        res.status(400).send('Missing uid in metadata');
        return;
      }

      const userRef = db.collection('users').doc(uid);
      await userRef.update({
        verificationLevel: 2,
        verifiedAt: FieldValue.serverTimestamp(),
      });

      console.log(`用户 ${uid} 身份验证通过，verificationLevel 升级为 2`);
    } else if (event.type === 'identity.verification_session.requires_input') {
      const session = event.data.object;
      console.log(`验证 session ${session.id} 需要用户补充输入`);
    }

    res.status(200).json({ received: true });
  });
