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

const db = admin.firestore();

// ─────────────────────────────────────────────────────
// 发起押金冻结（用户确认参加 + 有押金要求时调用）
// ─────────────────────────────────────────────────────
exports.freezeDeposit = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId, payChannel } = data; // payChannel: 'wechat' | 'alipay'
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
    if (user.sesameAuthorized && user.sesameScore >= 750) {
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
  .region('asia-east1')
  .https.onRequest(async (req, res) => {
    // TODO: 验证支付平台签名（防止伪造回调）
    // const isValid = WechatPay.verifySignature(req.headers, req.body);
    // if (!isValid) { res.status(400).send('Invalid signature'); return; }

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
  .region('asia-east1')
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
