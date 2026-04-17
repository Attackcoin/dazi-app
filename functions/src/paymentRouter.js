/**
 * 全球支付路由器（T5-14）
 * 根据用户区域自动选择支付方式
 *
 * 海外用户 → Stripe（已集成）
 * 国内用户 → 微信支付 / 支付宝
 *
 * 包含：
 * - createUnifiedPayment     统一支付入口 (onCall)
 * - wechatPayCallback        微信支付回调 (onRequest)
 * - alipayCallback           支付宝回调 (onRequest)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

const db = admin.firestore();

// 支持的支付渠道
const PayChannel = {
  STRIPE: 'stripe',
  WECHAT: 'wechat',
  ALIPAY: 'alipay',
};

// ─────────────────────────────────────────────────────
// 统一支付入口：自动路由到对应支付渠道
// ─────────────────────────────────────────────────────
exports.createUnifiedPayment = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const { postId, payChannel } = data;
    const uid = context.auth.uid;

    if (!postId) {
      throw new functions.https.HttpsError('invalid-argument', 'postId 不能为空');
    }

    // 获取帖子
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw new functions.https.HttpsError('not-found', '帖子不存在');
    }
    const post = postDoc.data();

    // 确定支付金额（参与费或押金）
    const amount = post.participationFee || post.depositAmount || 0;
    if (amount <= 0) {
      return { success: true, message: '无需支付' };
    }

    // 确定支付渠道
    const channel = payChannel || _resolvePayChannel(context);

    switch (channel) {
      case PayChannel.STRIPE:
        return await _createStripePayment(postId, uid, post, amount);
      case PayChannel.WECHAT:
        return await _createWechatPayment(postId, uid, post, amount);
      case PayChannel.ALIPAY:
        return await _createAlipayPayment(postId, uid, post, amount);
      default:
        throw new functions.https.HttpsError(
          'invalid-argument',
          `不支持的支付渠道: ${channel}`,
        );
    }
  });

// ─────────────────────────────────────────────────────
// 内部：根据请求上下文推断支付渠道
// ─────────────────────────────────────────────────────
function _resolvePayChannel(context) {
  // MVP 阶段简单策略：默认 Stripe
  // 后续可根据 IP 地理位置、用户设置等判断
  return PayChannel.STRIPE;
}

// ─────────────────────────────────────────────────────
// Stripe 支付（复用已有逻辑）
// ─────────────────────────────────────────────────────
async function _createStripePayment(postId, uid, post, amount) {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error('STRIPE_SECRET_KEY not configured');
  const stripe = require('stripe')(key);

  const amountCents = Math.round(amount * 100);
  const paymentId = `${postId}_${uid}`;

  // 幂等检查
  const existing = await db.collection('activityPayments').doc(paymentId).get();
  if (existing.exists && existing.data().status === 'paid') {
    return { alreadyPaid: true, channel: PayChannel.STRIPE };
  }

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    line_items: [{
      price_data: {
        currency: 'usd',
        product_data: { name: post.title },
        unit_amount: amountCents,
      },
      quantity: 1,
    }],
    metadata: { postId, uid, paymentId },
    success_url: `https://dazi-prod-9c9d6.web.app/payment-success?postId=${postId}`,
    cancel_url: `https://dazi-prod-9c9d6.web.app/p/${postId}`,
  });

  await db.collection('activityPayments').doc(paymentId).set({
    postId, uid,
    publisherId: post.userId,
    amount, amountCents,
    channel: PayChannel.STRIPE,
    stripeSessionId: session.id,
    checkoutUrl: session.url,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  return { checkoutUrl: session.url, channel: PayChannel.STRIPE };
}

// ─────────────────────────────────────────────────────
// 微信支付（骨架 — 需要微信商户号）
// ─────────────────────────────────────────────────────
async function _createWechatPayment(postId, uid, post, amount) {
  // TODO: 接入微信支付 JSAPI / Native / App 支付
  // 需要：微信商户号 + API v3 密钥 + 商户证书
  //
  // 流程：
  // 1. 调用 POST /v3/pay/transactions/app 创建预支付订单
  // 2. 返回 prepay_id 给客户端
  // 3. 客户端拉起微信支付 SDK
  // 4. 微信异步回调 wechatPayCallback
  //
  // 参考文档：https://pay.weixin.qq.com/wiki/doc/apiv3/apis/

  const paymentId = `${postId}_${uid}`;
  const amountFen = Math.round(amount * 100 * 7.2); // USD → CNY (粗略汇率)

  await db.collection('activityPayments').doc(paymentId).set({
    postId, uid,
    publisherId: post.userId,
    amount,
    amountLocal: amountFen,
    currency: 'CNY',
    channel: PayChannel.WECHAT,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  // 返回占位响应 —— 真实集成时返回 prepay_id + sign
  return {
    channel: PayChannel.WECHAT,
    status: 'pending_sdk_integration',
    message: '微信支付接入中，请使用 Stripe 支付',
  };
}

// ─────────────────────────────────────────────────────
// 支付宝（骨架 — 需要支付宝商户号）
// ─────────────────────────────────────────────────────
async function _createAlipayPayment(postId, uid, post, amount) {
  // TODO: 接入支付宝 App 支付
  // 需要：支付宝应用 ID + 应用私钥 + 支付宝公钥
  //
  // 流程：
  // 1. 调用 alipay.trade.app.pay 生成订单字符串
  // 2. 返回 orderString 给客户端
  // 3. 客户端拉起支付宝 SDK
  // 4. 支付宝异步回调 alipayCallback
  //
  // 参考文档：https://opendocs.alipay.com/open/204/105051

  const paymentId = `${postId}_${uid}`;
  const amountFen = Math.round(amount * 7.2 * 100);

  await db.collection('activityPayments').doc(paymentId).set({
    postId, uid,
    publisherId: post.userId,
    amount,
    amountLocal: amountFen,
    currency: 'CNY',
    channel: PayChannel.ALIPAY,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp(),
  });

  return {
    channel: PayChannel.ALIPAY,
    status: 'pending_sdk_integration',
    message: '支付宝接入中，请使用 Stripe 支付',
  };
}

// ─────────────────────────────────────────────────────
// 微信支付回调
// ─────────────────────────────────────────────────────
exports.wechatPayCallback = functions
  .region('asia-southeast1')
  .https.onRequest(async (req, res) => {
    // TODO: 验证微信签名
    // 参考：https://pay.weixin.qq.com/wiki/doc/apiv3/wechatpay/wechatpay4_1.shtml

    const { out_trade_no, trade_state } = req.body?.resource?.ciphertext || {};

    if (trade_state === 'SUCCESS' && out_trade_no) {
      const snap = await db.collection('activityPayments')
        .where('wechatOutTradeNo', '==', out_trade_no)
        .limit(1)
        .get();

      if (!snap.empty) {
        await snap.docs[0].ref.update({
          status: 'paid',
          paidAt: FieldValue.serverTimestamp(),
        });
      }
    }

    res.status(200).json({ code: 'SUCCESS', message: '成功' });
  });

// ─────────────────────────────────────────────────────
// 支付宝回调
// ─────────────────────────────────────────────────────
exports.alipayCallback = functions
  .region('asia-southeast1')
  .https.onRequest(async (req, res) => {
    // TODO: 验证支付宝签名
    // 参考：https://opendocs.alipay.com/open/200/106120

    const { out_trade_no, trade_status } = req.body || {};

    if (trade_status === 'TRADE_SUCCESS' && out_trade_no) {
      const snap = await db.collection('activityPayments')
        .where('alipayOutTradeNo', '==', out_trade_no)
        .limit(1)
        .get();

      if (!snap.empty) {
        await snap.docs[0].ref.update({
          status: 'paid',
          paidAt: FieldValue.serverTimestamp(),
        });
      }
    }

    res.send('success');
  });
