/**
 * 按活动付费模块（T5-11）
 * 帖子可设"参与费" — 区别于押金（可退），参与费不退
 * 平台抽 15%，其余在活动完成后转给发布者
 *
 * 包含：
 * - createPaymentSession    创建 Stripe Checkout Session (onCall)
 * - paymentWebhook          Stripe Webhook 处理支付成功
 * - settlePayments          定时任务：活动完成后分账给发布者
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = admin.firestore();

const PLATFORM_FEE_PERCENT = 15; // 平台抽成 15%

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) throw new Error('STRIPE_SECRET_KEY not configured');
  return require('stripe')(key);
}

// ─────────────────────────────────────────────────────
// 创建 Stripe Checkout Session (onCall)
// 用户申请加入付费活动时调用
// ─────────────────────────────────────────────────────
exports.createPaymentSession = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', '请先登录');
    }

    const { postId } = data;
    if (!postId) {
      throw new functions.https.HttpsError('invalid-argument', 'postId 不能为空');
    }

    const uid = context.auth.uid;

    // 获取帖子信息
    const postDoc = await db.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw new functions.https.HttpsError('not-found', '帖子不存在');
    }

    const post = postDoc.data();

    if (!post.participationFee || post.participationFee <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        '该活动不需要支付参与费',
      );
    }

    if (post.userId === uid) {
      throw new functions.https.HttpsError(
        'permission-denied',
        '发布者无需支付参与费',
      );
    }

    // 检查是否已支付（幂等）
    const paymentId = `${postId}_${uid}`;
    const existingPayment = await db.collection('activityPayments').doc(paymentId).get();
    if (existingPayment.exists) {
      const existing = existingPayment.data();
      if (existing.status === 'paid') {
        return { alreadyPaid: true };
      }
      // pending 状态：返回已有的 session URL
      if (existing.status === 'pending' && existing.checkoutUrl) {
        return { checkoutUrl: existing.checkoutUrl, resumed: true };
      }
    }

    const stripe = getStripe();
    const amountCents = Math.round(post.participationFee * 100);
    const platformFeeCents = Math.round(amountCents * PLATFORM_FEE_PERCENT / 100);

    // 创建 Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [{
        price_data: {
          currency: 'usd',
          product_data: {
            name: post.title,
            description: `参与费 — ${post.category}`,
          },
          unit_amount: amountCents,
        },
        quantity: 1,
      }],
      metadata: {
        postId,
        uid,
        paymentId,
        platformFeeCents: String(platformFeeCents),
      },
      success_url: `https://dazi-prod-9c9d6.web.app/payment-success?postId=${postId}`,
      cancel_url: `https://dazi-prod-9c9d6.web.app/p/${postId}`,
    });

    // 记录 pending payment
    await db.collection('activityPayments').doc(paymentId).set({
      postId,
      uid,
      publisherId: post.userId,
      amount: post.participationFee,
      amountCents,
      platformFeeCents,
      publisherAmountCents: amountCents - platformFeeCents,
      stripeSessionId: session.id,
      checkoutUrl: session.url,
      status: 'pending',
      createdAt: FieldValue.serverTimestamp(),
    });

    return { checkoutUrl: session.url };
  });

// ─────────────────────────────────────────────────────
// Stripe Webhook：支付成功
// ─────────────────────────────────────────────────────
exports.paymentWebhook = functions
  .region('asia-southeast1')
  .https.onRequest(async (req, res) => {
    const stripe = getStripe();
    const endpointSecret = process.env.STRIPE_PAYMENT_WEBHOOK_SECRET;

    let event;
    if (endpointSecret) {
      const sig = req.headers['stripe-signature'];
      try {
        event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
      } catch (err) {
        console.error('Webhook 签名验证失败:', err.message);
        res.status(400).send(`Webhook Error: ${err.message}`);
        return;
      }
    } else {
      event = req.body;
    }

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object;
      const { paymentId, postId, uid } = session.metadata || {};

      if (paymentId) {
        await db.collection('activityPayments').doc(paymentId).update({
          status: 'paid',
          stripePaymentIntentId: session.payment_intent,
          paidAt: FieldValue.serverTimestamp(),
        });

        console.log(`活动付费成功 paymentId=${paymentId} postId=${postId} uid=${uid}`);
      }
    }

    res.status(200).json({ received: true });
  });

// ─────────────────────────────────────────────────────
// 定时任务：活动完成后将参与费（扣除平台抽成）转给发布者
// 每小时运行一次
// ─────────────────────────────────────────────────────
exports.settlePayments = functions
  .region('asia-southeast1')
  .pubsub.schedule('every 1 hours')
  .onRun(async () => {
    // 查找所有已付费但未结算的 payment
    const pendingSettlements = await db.collection('activityPayments')
      .where('status', '==', 'paid')
      .limit(100)
      .get();

    let settled = 0;

    for (const doc of pendingSettlements.docs) {
      const payment = doc.data();

      // 检查对应的 match 是否已完成
      // 通过 postId 找到对应 match
      const matchSnap = await db.collection('matches')
        .where('postId', '==', payment.postId)
        .where('status', '==', 'completed')
        .limit(1)
        .get();

      if (matchSnap.empty) continue; // 活动未完成，跳过

      // 标记为 settled（实际转账需要 Stripe Connect / Stripe Transfer）
      // MVP 阶段记录应转金额，人工转账
      await doc.ref.update({
        status: 'settled',
        settledAt: FieldValue.serverTimestamp(),
      });

      settled++;
      console.log(
        `结算 paymentId=${doc.id} 发布者=${payment.publisherId} ` +
        `金额=${payment.publisherAmountCents / 100} USD`,
      );
    }

    if (settled > 0) {
      console.log(`本次结算 ${settled} 笔活动付费`);
    }
  });
