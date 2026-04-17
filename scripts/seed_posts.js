#!/usr/bin/env node

/**
 * 种子数据脚本 — 往 Firestore (dazi-dev) 写入测试帖子。
 * 使用 Firebase CLI 缓存的 access token + Firestore REST API。
 *
 * 用法：cd dazi-app && node scripts/seed_posts.js
 * 前提：firebase login 已完成。
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const PROJECT_ID = 'dazi-prod-9c9d6';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// ── 获取 access token ──

function getAccessToken() {
  const configPath = path.join(
    process.env.HOME || process.env.USERPROFILE,
    '.config', 'configstore', 'firebase-tools.json'
  );
  const config = JSON.parse(fs.readFileSync(configPath, 'utf-8'));

  const accessToken = config.tokens?.access_token;
  const refreshToken = config.tokens?.refresh_token;
  const expiresAt = config.tokens?.expires_at;

  // 如果 token 未过期，直接用
  if (accessToken && expiresAt && Date.now() < expiresAt) {
    return Promise.resolve(accessToken);
  }

  // token 过期了，用 refresh_token 刷新
  if (!refreshToken) {
    throw new Error('找不到 refresh token，请运行 firebase login');
  }

  return new Promise((resolve, reject) => {
    // Firebase CLI 的 OAuth client ID
    const clientId = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
    const clientSecret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
    const body = `grant_type=refresh_token&client_id=${clientId}&client_secret=${clientSecret}&refresh_token=${refreshToken}`;

    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    }, (res) => {
      let data = '';
      res.on('data', (d) => data += d);
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(new Error(`Token refresh failed: ${res.statusCode} ${data}`));
          return;
        }
        const json = JSON.parse(data);
        resolve(json.access_token);
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── Firestore REST helper ──

function firestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    return Number.isInteger(val) ? { integerValue: String(val) } : { doubleValue: val };
  }
  if (val instanceof Date) {
    return { timestampValue: val.toISOString() };
  }
  if (Array.isArray(val)) {
    return { arrayValue: { values: val.map(firestoreValue) } };
  }
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) {
      fields[k] = firestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function createDocument(token, collectionPath, data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = firestoreValue(v);
  }

  const body = JSON.stringify({ fields });
  const url = new URL(`${BASE_URL}/${collectionPath}`);

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', (d) => data += d);
      res.on('end', () => {
        if (res.statusCode >= 300) {
          reject(new Error(`Firestore write failed: ${res.statusCode} ${data}`));
          return;
        }
        resolve(JSON.parse(data));
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

/// 用 PATCH 按指定 documentId 写入（REST API 的 createDocument 不支持自定义 ID，
/// 但 PATCH 带 updateMask 空参数等价于 set）。
function setDocument(token, collectionPath, docId, data) {
  const fields = {};
  for (const [k, v] of Object.entries(data)) {
    fields[k] = firestoreValue(v);
  }

  const body = JSON.stringify({ fields });
  const url = new URL(`${BASE_URL}/${collectionPath}/${docId}`);

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', (d) => data += d);
      res.on('end', () => {
        if (res.statusCode >= 300) {
          reject(new Error(`Firestore write failed: ${res.statusCode} ${data}`));
          return;
        }
        resolve(JSON.parse(data));
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

// ── 测试帖子数据 ──

function randomUid() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let uid = '';
  for (let i = 0; i < 28; i++) uid += chars[Math.floor(Math.random() * chars.length)];
  return uid;
}

const fakeNames = ['小明', '阿花', '大壮', '小美', '阿杰', '佳佳', '老王', '小李', '阿宝', '萌萌', '大飞', '晓晓'];

const posts = [
  {
    category: '美食', title: '周末火锅局！川味牛油锅底🔥',
    description: '找几个朋友一起吃海底捞，我已经订好了 4 人位，还差 2 个人。不用社交压力，安静吃就行～',
    totalSlots: 4, minSlots: 2, costType: 'aa', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: '海底捞（三里屯店）', city: '北京', lat: 39.9336, lng: 116.4532 }, hoursFromNow: 48,
  },
  {
    category: '运动', title: '羽毛球双打约起来 🏸',
    description: '每周三晚上 7 点在体育馆打羽毛球，水平不限，重在参与开心！提供球拍。',
    totalSlots: 4, minSlots: 2, costType: 'aa', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '朝阳体育馆', city: '北京', lat: 39.9219, lng: 116.4435 }, hoursFromNow: 72,
  },
  {
    category: '游戏', title: '剧本杀新本首发！推理向 🔍',
    description: '朋友店里出了个新本，6 人推理本，需要 4 个玩家。欢迎萌新，DM 会带节奏。',
    totalSlots: 6, minSlots: 4, costType: 'aa', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '迷雾剧本杀', city: '上海', lat: 31.2304, lng: 121.4737 }, hoursFromNow: 36,
  },
  {
    category: '美食', title: '工作日午餐搭子 🍜',
    description: '在科技园附近上班，每天中午不知道吃什么，找个人一起探店。今天试试那家新开的云南米线。',
    totalSlots: 2, minSlots: 2, costType: 'self', isSocialAnxietyFriendly: true, isInstant: true,
    location: { name: '南山科技园', city: '深圳', lat: 22.5362, lng: 113.9299 }, hoursFromNow: 4,
  },
  {
    category: '运动', title: '夜跑团招新 🏃‍♀️',
    description: '每周二四晚上 8 点从奥森南门出发，5km 慢跑配速 6-7 分钟，跑完喝椰子水。新手友好！',
    totalSlots: 8, minSlots: 3, costType: 'self', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: '奥林匹克森林公园南门', city: '北京', lat: 40.0147, lng: 116.3932 }, hoursFromNow: 52,
  },
  {
    category: '娱乐', title: '周五桌游之夜 🎲',
    description: '卡坦岛、璀璨宝石、阿瓦隆…… 游戏随便选，重点是开心。带了零食和饮料。',
    totalSlots: 6, minSlots: 3, costType: 'host', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '我家客厅（静安区）', city: '上海', lat: 31.2286, lng: 121.4524 }, hoursFromNow: 80,
  },
  {
    category: '学习', title: '咖啡馆自习室 ☕📖',
    description: '找个人一起去咖啡馆学习，互相监督不摸鱼。我在准备考研，你学什么都行。',
    totalSlots: 3, minSlots: 2, costType: 'self', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: 'Manner Coffee（天目西路）', city: '上海', lat: 31.2456, lng: 121.4570 }, hoursFromNow: 24,
  },
  {
    category: '旅行', title: '周末自驾去千岛湖 🚗🏞️',
    description: '计划这周末自驾去千岛湖玩两天，住湖边民宿，钓鱼烧烤看星星。还能坐 2 人，油费 AA。',
    totalSlots: 4, minSlots: 2, costType: 'aa', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '千岛湖风景区', city: '杭州', lat: 29.6049, lng: 119.0029 }, hoursFromNow: 60,
  },
  {
    category: '美食', title: '串串香走起！🍢',
    description: '下班后去吃那家网红串串，据说签签 5 毛钱一根，便宜又好吃。求搭子！',
    totalSlots: 4, minSlots: 2, costType: 'aa', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: '马路边边麻辣烫（春熙路）', city: '成都', lat: 30.6571, lng: 104.0668 }, hoursFromNow: 28,
  },
  {
    category: '运动', title: '篮球 3v3 半场 🏀',
    description: '周六下午在天河体育中心打半场，目前 4 个人差 2 个。水平业余，打着玩。',
    totalSlots: 6, minSlots: 4, costType: 'self', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '天河体育中心', city: '广州', lat: 23.1372, lng: 113.3210 }, hoursFromNow: 44,
  },
  {
    category: '娱乐', title: 'KTV 麦霸夜 🎤',
    description: '包了个中包，能坐 8 个人。目前 3 个，欢迎加入！什么歌都能唱，不嫌弃跑调的。',
    totalSlots: 8, minSlots: 3, costType: 'aa', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '好乐迪 KTV（五道口）', city: '北京', lat: 39.9926, lng: 116.3383 }, hoursFromNow: 32,
  },
  {
    category: '学习', title: '英语角练口语 🗣️',
    description: '每周日下午 2 点在公园，纯英文聊天 1 小时。话题自由，不纠错不尴尬，练胆为主。',
    totalSlots: 10, minSlots: 3, costType: 'self', isSocialAnxietyFriendly: false, isInstant: false,
    location: { name: '人民公园', city: '成都', lat: 30.6625, lng: 104.0595 }, hoursFromNow: 90,
  },
  {
    category: '美食', title: '下午茶探店：新开的日式甜品 🍰',
    description: '看到大众点评新开了一家日式甜品店评分 4.8，想去试试但一个人不好意思，求搭子一起！',
    totalSlots: 3, minSlots: 2, costType: 'self', isSocialAnxietyFriendly: true, isInstant: true,
    location: { name: '和茶甜品（南京西路）', city: '上海', lat: 31.2302, lng: 121.4500 }, hoursFromNow: 6,
  },
  {
    category: '旅行', title: '骑行大运河绿道 🚴',
    description: '周末骑行大运河绿道，单程 20km，来回大概 3 小时。有自行车的直接来，没有的可以租。',
    totalSlots: 6, minSlots: 2, costType: 'self', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: '京杭大运河起点', city: '杭州', lat: 30.3180, lng: 120.1625 }, hoursFromNow: 56,
  },
  {
    category: '游戏', title: 'Switch 马里奥派对之夜 🎮',
    description: '在家组了个 Switch 游戏趴，主打马里奥派对和任天堂明星大乱斗。提供手柄和零食。',
    totalSlots: 4, minSlots: 2, costType: 'host', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: '我家（西湖区）', city: '杭州', lat: 30.2590, lng: 120.1307 }, hoursFromNow: 70,
  },
  {
    category: '演出', title: '五月天演唱会拼车搭子 🎤',
    description: '下周六五月天上海站，一起拼车去梅赛德斯中心看演唱会！演出结束后一起打车回来。',
    totalSlots: 4, minSlots: 2, costType: 'aa', isSocialAnxietyFriendly: false, isInstant: false,
    depositAmount: 50,
    location: { name: '梅赛德斯-奔驰文化中心', city: '上海', lat: 31.1894, lng: 121.4737 }, hoursFromNow: 96,
  },
  {
    category: '演出', title: '草莓音乐节搭子 🎵',
    description: '五一草莓音乐节组队去！已买好票，找几个人一起嗨。可以分摊交通和住宿。',
    totalSlots: 6, minSlots: 3, costType: 'aa', isSocialAnxietyFriendly: false, isInstant: false,
    depositAmount: 100,
    location: { name: '上海国际音乐村', city: '上海', lat: 31.0961, lng: 121.2440 }, hoursFromNow: 120,
  },
  {
    category: '演出', title: '看展搭子：teamLab 无界 🎨',
    description: 'teamLab 无界上海站开了，找个人一起去看！拍照超好看，一个人去有点尴尬。',
    totalSlots: 3, minSlots: 2, costType: 'self', isSocialAnxietyFriendly: true, isInstant: false,
    location: { name: 'teamLab 无界上海', city: '上海', lat: 31.2412, lng: 121.5001 }, hoursFromNow: 48,
  },
  {
    category: '演出', title: 'CBA 总决赛现场助威 🏀',
    description: 'CBA 总决赛第三场！找几个球迷一起去现场助威，一起喊加油更带劲。',
    totalSlots: 4, minSlots: 2, costType: 'self', isSocialAnxietyFriendly: false, isInstant: false,
    depositAmount: 30,
    location: { name: '五棵松体育馆', city: '北京', lat: 39.9074, lng: 116.2789 }, hoursFromNow: 64,
  },
];

// ── 主逻辑 ──

async function seed() {
  console.log('🔑 获取 access token...');
  const token = await getAccessToken();

  console.log(`📝 开始写入 ${posts.length} 条帖子到 Firestore (${PROJECT_ID})...`);
  const now = new Date();

  let success = 0;
  for (const p of posts) {
    const uid = randomUid();
    const name = fakeNames[Math.floor(Math.random() * fakeNames.length)];
    const timeDate = new Date(Date.now() + p.hoursFromNow * 3600 * 1000);
    const expiresDate = new Date(timeDate.getTime() + 2 * 3600 * 1000);

    // 先创建发布者的 user 文档（帖子详情页会查 userByIdProvider）
    const userDoc = {
      name: name,
      avatar: '',
      bio: '搭子爱好者',
      gender: Math.random() > 0.5 ? 'male' : 'female',
      city: p.location.city,
      tags: [p.category],
      sesameAuthorized: false,
      rating: 4.5 + Math.random() * 0.5,
      reviewCount: Math.floor(Math.random() * 20),
      ratingSum: 0,
      ratingCount: 0,
      ghostCount: 0,
      totalMeetups: Math.floor(Math.random() * 15),
      badges: [],
      isRestricted: false,
      createdAt: now,
      updatedAt: now,
    };

    const postData = {
      userId: uid,
      category: p.category,
      title: p.title,
      description: p.description,
      images: [],
      time: timeDate,
      location: p.location,
      totalSlots: p.totalSlots,
      minSlots: p.minSlots,
      genderQuota: null,
      acceptedGender: { male: 0, female: 0 },
      costType: p.costType,
      depositAmount: p.depositAmount || 0,
      isInstant: p.isInstant,
      isSocialAnxietyFriendly: p.isSocialAnxietyFriendly,
      status: 'open',
      waitlist: [],
      createdAt: now,
      expiresAt: expiresDate,
      publisherName: name,
      publisherAvatar: '',
    };

    try {
      await setDocument(token, 'users', uid, userDoc);
      await createDocument(token, 'posts', postData);
      success++;
      process.stdout.write(`  ✓ [${success}/${posts.length}] ${p.title} (by ${name})\n`);
    } catch (err) {
      console.error(`  ✗ ${p.title}: ${err.message}`);
    }
  }

  console.log(`\n✅ 完成！成功写入 ${success}/${posts.length} 条帖子`);
}

seed().catch((err) => {
  console.error('❌ 失败:', err.message);
  process.exit(1);
});
