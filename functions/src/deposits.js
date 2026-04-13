/**
 * 押金模块
 * 处理押金冻结/释放/扣除（通过微信/支付宝担保交易）
 *
 * 重要法律说明：
 * 使用"担保交易"模式 — 资金由支付平台托管，App不直接持有
 * 这样规避"二清"违规风险（未持牌机构不能直接持有用户资金）
 *
 * 注意：实际支付 API 调用需要接入微信支付/支付宝 SDK
 * 本文件提供逻辑框架，支付 SDK 接入见 README
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 内部：HMAC-SHA256 签名验证（临时保护，生产环境需替换为真实支付平台签名验证）
// 调用方需在请求头 x-dazi-signature 中携带 HMAC-SHA256(secret, body)
// ─────────────────────────────────────────────────────
function verifyCallbackSignature(req) {
  const secret = process.env.PAYMENT_CALLBACK_SECRET;
  if (!secret) {
    // TODO: 配置 PAYMENT_CALLBACK_SECRET 环境变量
    // 生产环境未配置时拒绝所有请求，防止未保护的回调被滥用
    console.error('PAYMENT_CALLBACK_SECRET 未配置，拒绝回调请求');
    return false;
  }
  const signature = req.headers['x-dazi-signature'];
  if (!signature) return false;

  const body = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex');

  // 使用 timingSafeEqual 防止时序攻击
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signature, 'hex'),
      Buffer.from(expected, 'hex')
    );
  } catch {
    return false;
  }
}

// 合法支付渠道枚举
const VALID_PAY_CHANNELS = ['wechat', 'alipay'];

// ─────────────────────────────────────────────────────
// 发起押金冻结（用户确认参加 + 有押金要求时调用）
// ─────────────────────────────────────────────────────
exports.freezeDeposit = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId, payChannel } = data; // payChannel: 'wechat' | 'alipay'

    // 枚举校验：防止注入非法渠道
    if (!VALID_PAY_CHANNELS.includes(payChannel)) {
      throw new functions.https.HttpsError('invalid-argument', `payChannel 无效，必须是 ${VALID_PAY_CHANNELS.join(' 或 ')}`);
    }
    const uid = context.auth.uid;

    const matchDoc = await db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');

    const match = matchDoc.data();
    if (!match.participants.includes(uid)) {
      throw new functions.https.HttpsError('permission-denied', '你不是该搭子的参与者');
    }

    const postDoc = await db.collection('posts').doc(match.postId).get();
    const post = postDoc.data();

    if (!post.depositAmount || post.depositAmount === 0) {
      return { success: true, message: '该搭子无需押金' };
    }

    // 检查芝麻信用是否可以免押金
    const userDoc = await db.collection('users').doc(uid).get();
    const user = userDoc.data();
    // 注：AppUser 模型只有 sesameAuthorized (bool)，没有 sesameScore 字段。
    // 原逻辑 `sesameAuthorized && sesameScore >= 750` 永为 false（sesameScore 恒 undefined）。
    // D3 信用承诺 MVP 下本函数为 dead code，此处仅修复字段不一致 bug。
    if (user.sesameAuthorized) {
      // 芝麻信用担保，无需实际押金
      await db.collection('deposits').add({
        userId: uid,
        matchId,
        amount: post.depositAmount,
        status: 'sesame_guaranteed',
        payChannel: 'sesame',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: true, method: 'sesame', message: '芝麻信用担保，无需缴纳押金' };
    }

    // 创建支付订单（调用微信/支付宝担保交易）
    const orderId = `dazi_${matchId}_${uid}_${Date.now()}`;

    // TODO: 接入微信支付/支付宝担保交易 SDK
    // const payResult = await WechatPay.createEscrowOrder({
    //   orderId,
    //   amount: post.depositAmount * 100, // 单位：分
    //   description: `搭子押金-${post.title}`,
    //   userId: uid,
    // });

    // 记录押金（待支付状态）
    await db.collection('deposits').add({
      userId: uid,
      matchId,
      amount: post.depositAmount,
      status: 'pending_payment',
      payChannel,
      orderId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 返回支付参数（前端唤起支付 SDK）
    return {
      success: true,
      orderId,
      amount: post.depositAmount,
      payChannel,
      // payParams: payResult.params, // 微信/支付宝支付参数
    };
  });

// ─────────────────────────────────────────────────────
// 押金支付成功回调（微信/支付宝异步通知）
// 生产环境：配置为支付平台的 Webhook URL
// ─────────────────────────────────────────────────────
exports.depositPaymentCallback = functions
  .region('asia-southeast1')
  .https.onRequest(async (req, res) => {
    // 签名验证：当前使用基于 PAYMENT_CALLBACK_SECRET 的 HMAC-SHA256 临时保护
    // TODO: 接入真实支付平台（微信支付/支付宝）后，替换为官方 SDK 的签名验证方法：
    //   微信支付 v3: WechatPay.verifySignature(req.headers, req.body, cert)
    //   支付宝:      AlipaySdk.verifyNotify(req.body)
    if (!verifyCallbackSignature(req)) {
      res.status(401).send('Invalid signature');
      return;
    }

    const { orderId, status } = req.body;

    if (status === 'SUCCESS') {
      const depositQuery = await db.collection('deposits')
        .where('orderId', '==', orderId)
        .limit(1)
        .get();

      if (!depositQuery.empty) {
        await depositQuery.docs[0].ref.update({
          status: 'frozen',
          frozenAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    res.status(200).send('OK');
  });

// ─────────────────────────────────────────────────────
// 押金退款（取消活动/提前退出）
// ─────────────────────────────────────────────────────
exports.refundDeposit = functions
  .region('asia-southeast1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId } = data;
    const uid = context.auth.uid;

    const depositQuery = await db.collection('deposits')
      .where('userId', '==', uid)
      .where('matchId', '==', matchId)
      .where('status', '==', 'frozen')
      .limit(1)
      .get();

    if (depositQuery.empty) {
      return { success: true, message: '无需退款的押金' };
    }

    const deposit = depositQuery.docs[0];

    // 计算退款比例（根据距见面时间）
    const matchDoc = await db.collection('matches').doc(matchId).get();
    const hoursUntilMeet = (matchDoc.data().meetTime.toDate() - Date.now()) / 1000 / 3600;

    let refundRatio = 0;
    if (hoursUntilMeet >= 24) refundRatio = 1.0;        // 24h前取消：全退
    else if (hoursUntilMeet >= 2) refundRatio = 0.5;    // 2-24h取消：退50%
    // 当天取消或不到：不退（ratio = 0）

    const refundAmount = Math.floor(deposit.data().amount * refundRatio);

    // TODO: 调用支付平台退款接口
    // await WechatPay.refund({ orderId: deposit.data().orderId, amount: refundAmount * 100 });

    await deposit.ref.update({
      status: 'refunded',
      refundAmount,
      refundRatio,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, refundAmount, refundRatio };
  });
