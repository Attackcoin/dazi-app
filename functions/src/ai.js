/**
 * AI 功能模块
 * 所有 Claude Haiku API 调用都通过这里，密钥不暴露给前端
 *
 * 包含：
 * - parseVoicePost    语音发布解析 → 结构化表单字段
 * - generateDescription  AI描述助手 → 活动描述文案
 * - generateIcebreakers  破冰话题 → 见面前个性化话题
 * - generateRecapCard    搭子回忆卡 → 活动后趣味总结
 * - generateMonthlyReport 社交成长月报 → 每月1日自动生成
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Anthropic = require('@anthropic-ai/sdk');

const db = admin.firestore();

// Claude 客户端（Key 存在 Firebase Functions 环境变量里）
function getClaudeClient() {
  const apiKey = process.env.CLAUDE_API_KEY;
  if (!apiKey) throw new Error('CLAUDE_API_KEY not configured');
  return new Anthropic({ apiKey });
}

// ─────────────────────────────────────────────────────
// 语音发布解析
// 输入：用户说的一句话（已经过设备 STT 转成文字）
// 输出：结构化的搭子表单字段
// ─────────────────────────────────────────────────────
exports.parseVoicePost = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { text } = data;
    if (!text || text.trim().length === 0) {
      throw new functions.https.HttpsError('invalid-argument', '语音文字不能为空');
    }

    const claude = getClaudeClient();
    const today = new Date().toLocaleDateString('zh-CN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

    const message = await claude.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 500,
      messages: [{
        role: 'user',
        content: `今天是${today}。

用户说：「${text}」

请从这句话提取搭子活动信息，返回 JSON 格式（只返回 JSON，不要其他文字）：
{
  "category": "一级分类 > 二级分类，从[吃喝>吃饭/喝酒/下午茶/奶茶/烧烤/火锅, 运动>篮球/羽毛球/健身/跑步/游泳/爬山/骑行/瑜伽, 娱乐>剧本杀/密室/桌游/KTV/电影/演出/展览, 出行>周边游/自驾/旅游/逛街, 学习>自习/考研/考证/语言学习, 其他>撸猫/闲逛/其他]中选",
  "title": "简洁的活动标题，15字以内",
  "timeText": "时间描述，如'周六下午3点'，无法识别则返回null",
  "location": "地点名称，无法识别则返回null",
  "totalSlots": 总人数（含发布者），无法识别则返回3,
  "costType": "aa（AA制）/ host（发布者请客）/ self（自费）/ tbd（待定），无法识别则返回'aa'",
  "suggestedDescription": "根据信息生成的活动描述，2-3句话，口语化有吸引力"
}`
      }]
    });

    try {
      const parsed = JSON.parse(message.content[0].text);
      return { success: true, data: parsed };
    } catch {
      return { success: false, error: '解析失败，请手动填写' };
    }
  });

// ─────────────────────────────────────────────────────
// AI 描述助手
// 输入：标题 + 分类
// 输出：活动描述文案（2-3句话）
// ─────────────────────────────────────────────────────
exports.generateDescription = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { title, category } = data;
    if (!title) throw new functions.https.HttpsError('invalid-argument', '标题不能为空');

    const claude = getClaudeClient();

    const message = await claude.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 200,
      messages: [{
        role: 'user',
        content: `为以下搭子活动生成一段吸引人的描述（2-3句，口语化，有亲切感，结尾可加1个相关emoji）：

活动标题：${title}
活动分类：${category || '未知'}

只返回描述文字，不要其他内容。`
      }]
    });

    return { success: true, description: message.content[0].text.trim() };
  });

// ─────────────────────────────────────────────────────
// 破冰话题生成
// 输入：matchId（从中取出双方用户数据）
// 输出：3条个性化破冰话题
// ─────────────────────────────────────────────────────
exports.generateIcebreakers = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId } = data;
    const matchDoc = await db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) throw new functions.https.HttpsError('not-found', '搭子不存在');

    const match = matchDoc.data();
    const postDoc = await db.collection('posts').doc(match.postId).get();
    const post = postDoc.data();

    // 取出除当前用户外的其他参与者（最多2人，避免token过多）
    const otherIds = match.participants
      .filter(uid => uid !== context.auth.uid)
      .slice(0, 2);

    const [myDoc, ...otherDocs] = await Promise.all([
      db.collection('users').doc(context.auth.uid).get(),
      ...otherIds.map(uid => db.collection('users').doc(uid).get())
    ]);

    const me = myDoc.data();
    const others = otherDocs.map(d => d.data()).filter(Boolean);

    const otherTags = others.flatMap(u => u.tags || []).join('、');
    const myTags = (me.tags || []).join('、');

    const claude = getClaudeClient();
    const message = await claude.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 300,
      messages: [{
        role: 'user',
        content: `你们即将一起参加「${post.title}」（${post.category}）。

你的兴趣标签：${myTags || '未设置'}
对方兴趣标签：${otherTags || '未设置'}

请生成3条自然的破冰话题，帮助消除见面前的紧张感。格式：
1. [话题]
2. [话题]
3. [话题]

话题要具体、有趣、基于共同信息，不要泛泛而谈。`
      }]
    });

    const lines = message.content[0].text
      .split('\n')
      .filter(l => l.match(/^\d\./))
      .map(l => l.replace(/^\d\.\s*/, '').trim());

    return { success: true, topics: lines };
  });

// ─────────────────────────────────────────────────────
// 搭子回忆卡
// 在双方签到完成后由 antiGhosting 模块触发
// 输入：matchId
// 输出：回忆卡文案（存回 Firestore）
// ─────────────────────────────────────────────────────
exports.generateRecapCard = functions
  .region('asia-east1')
  .https.onCall(async (data, context) => {
    if (!context.auth) throw new functions.https.HttpsError('unauthenticated', '请先登录');

    const { matchId } = data;
    return await _generateRecapCard(matchId);
  });

// 内部函数（供 antiGhosting 模块调用）
async function _generateRecapCard(matchId) {
  const matchDoc = await db.collection('matches').doc(matchId).get();
  const match = matchDoc.data();
  const postDoc = await db.collection('posts').doc(match.postId).get();
  const post = postDoc.data();

  const duration = Math.round(
    (new Date() - post.time.toDate()) / 1000 / 60
  );

  const claude = getClaudeClient();
  const message = await claude.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 100,
    messages: [{
      role: 'user',
      content: `为这次搭子活动生成一句温暖有趣的总结（20字以内，第一人称，有代入感）：

活动：${post.title}（${post.category}）
地点：${post.location.name}
人数：${match.participants.length}人

只返回这一句话，不要其他内容。`
    }]
  });

  const summary = message.content[0].text.trim();

  // 存储回忆卡数据到 match 文档
  await db.collection('matches').doc(matchId).update({
    recapCard: {
      summary,
      activity: post.title,
      location: post.location.name,
      participants: match.participants.length,
      duration: duration > 0 ? duration : null,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }
  });

  return { success: true, summary };
}

exports._generateRecapCard = _generateRecapCard;

// ─────────────────────────────────────────────────────
// 社交成长月报
// 每月1日 00:05 自动触发（Cloud Scheduler）
// 为过去30天内有活动的用户生成月报
// ─────────────────────────────────────────────────────
exports.generateMonthlyReports = functions
  .region('asia-east1')
  .pubsub.schedule('5 0 1 * *')
  .timeZone('Asia/Shanghai')
  .onRun(async () => {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const monthEnd = new Date(now.getFullYear(), now.getMonth(), 1);

    // 找出上月有完成搭子的用户
    const completedMatches = await db.collection('matches')
      .where('status', '==', 'completed')
      .where('meetTime', '>=', monthStart)
      .where('meetTime', '<', monthEnd)
      .get();

    // 按用户统计数据
    const userStats = {};
    completedMatches.forEach(doc => {
      const match = doc.data();
      match.participants.forEach(uid => {
        if (!userStats[uid]) {
          userStats[uid] = { meetups: 0, uniquePeople: new Set(), matchIds: [] };
        }
        userStats[uid].meetups++;
        userStats[uid].matchIds.push(doc.id);
        match.participants.forEach(other => {
          if (other !== uid) userStats[uid].uniquePeople.add(other);
        });
      });
    });

    const claude = getClaudeClient();

    // 为每个活跃用户生成月报（批量处理，避免超时）
    const userIds = Object.keys(userStats);
    for (const uid of userIds) {
      const stats = userStats[uid];
      try {
        const message = await claude.messages.create({
          model: 'claude-haiku-4-5-20251001',
          max_tokens: 80,
          messages: [{
            role: 'user',
            content: `用户上个月完成了 ${stats.meetups} 次搭子，认识了 ${stats.uniquePeople.size} 位新朋友。生成一句温暖励志的月报结语（20字以内，鼓励继续走出去），只返回这句话。`
          }]
        });

        await db.collection('monthlyReports').add({
          userId: uid,
          month: `${now.getFullYear()}-${String(now.getMonth()).padStart(2, '0')}`,
          meetups: stats.meetups,
          newFriends: stats.uniquePeople.size,
          summary: message.content[0].text.trim(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (err) {
        console.error(`月报生成失败 uid=${uid}:`, err);
      }
    }

    console.log(`月报生成完成，共 ${userIds.length} 位用户`);
  });
