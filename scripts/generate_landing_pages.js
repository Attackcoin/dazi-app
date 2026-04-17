#!/usr/bin/env node
/**
 * SEO 着陆页矩阵生成器
 * "find [activity] partner in [city]" × 50 cities × 20 activities
 *
 * 输出目录：public/find/
 * URL 格式：/find/{activity-slug}-partner-in-{city-slug}
 *
 * 运行：node scripts/generate_landing_pages.js
 */

const fs = require('fs');
const path = require('path');

// ─── 数据 ────────────────────────────────────────────

const CITIES = [
  // 中国一线/新一线（20）
  { slug: 'beijing', zh: '北京', en: 'Beijing' },
  { slug: 'shanghai', zh: '上海', en: 'Shanghai' },
  { slug: 'guangzhou', zh: '广州', en: 'Guangzhou' },
  { slug: 'shenzhen', zh: '深圳', en: 'Shenzhen' },
  { slug: 'chengdu', zh: '成都', en: 'Chengdu' },
  { slug: 'hangzhou', zh: '杭州', en: 'Hangzhou' },
  { slug: 'wuhan', zh: '武汉', en: 'Wuhan' },
  { slug: 'nanjing', zh: '南京', en: 'Nanjing' },
  { slug: 'chongqing', zh: '重庆', en: 'Chongqing' },
  { slug: 'xian', zh: '西安', en: "Xi'an" },
  { slug: 'suzhou', zh: '苏州', en: 'Suzhou' },
  { slug: 'tianjin', zh: '天津', en: 'Tianjin' },
  { slug: 'changsha', zh: '长沙', en: 'Changsha' },
  { slug: 'zhengzhou', zh: '郑州', en: 'Zhengzhou' },
  { slug: 'dongguan', zh: '东莞', en: 'Dongguan' },
  { slug: 'qingdao', zh: '青岛', en: 'Qingdao' },
  { slug: 'kunming', zh: '昆明', en: 'Kunming' },
  { slug: 'dalian', zh: '大连', en: 'Dalian' },
  { slug: 'xiamen', zh: '厦门', en: 'Xiamen' },
  { slug: 'hefei', zh: '合肥', en: 'Hefei' },
  // 东南亚（10）
  { slug: 'singapore', zh: '新加坡', en: 'Singapore' },
  { slug: 'bangkok', zh: '曼谷', en: 'Bangkok' },
  { slug: 'kuala-lumpur', zh: '吉隆坡', en: 'Kuala Lumpur' },
  { slug: 'jakarta', zh: '雅加达', en: 'Jakarta' },
  { slug: 'ho-chi-minh', zh: '胡志明市', en: 'Ho Chi Minh City' },
  { slug: 'manila', zh: '马尼拉', en: 'Manila' },
  { slug: 'taipei', zh: '台北', en: 'Taipei' },
  { slug: 'hong-kong', zh: '香港', en: 'Hong Kong' },
  { slug: 'seoul', zh: '首尔', en: 'Seoul' },
  { slug: 'tokyo', zh: '东京', en: 'Tokyo' },
  // 北美（8）
  { slug: 'new-york', zh: '纽约', en: 'New York' },
  { slug: 'los-angeles', zh: '洛杉矶', en: 'Los Angeles' },
  { slug: 'san-francisco', zh: '旧金山', en: 'San Francisco' },
  { slug: 'toronto', zh: '多伦多', en: 'Toronto' },
  { slug: 'vancouver', zh: '温哥华', en: 'Vancouver' },
  { slug: 'seattle', zh: '西雅图', en: 'Seattle' },
  { slug: 'chicago', zh: '芝加哥', en: 'Chicago' },
  { slug: 'boston', zh: '波士顿', en: 'Boston' },
  // 欧洲（7）
  { slug: 'london', zh: '伦敦', en: 'London' },
  { slug: 'paris', zh: '巴黎', en: 'Paris' },
  { slug: 'berlin', zh: '柏林', en: 'Berlin' },
  { slug: 'amsterdam', zh: '阿姆斯特丹', en: 'Amsterdam' },
  { slug: 'madrid', zh: '马德里', en: 'Madrid' },
  { slug: 'barcelona', zh: '巴塞罗那', en: 'Barcelona' },
  { slug: 'munich', zh: '慕尼黑', en: 'Munich' },
  // 大洋洲（3）
  { slug: 'sydney', zh: '悉尼', en: 'Sydney' },
  { slug: 'melbourne', zh: '墨尔本', en: 'Melbourne' },
  { slug: 'auckland', zh: '奥克兰', en: 'Auckland' },
  // 中东（2）
  { slug: 'dubai', zh: '迪拜', en: 'Dubai' },
  { slug: 'abu-dhabi', zh: '阿布扎比', en: 'Abu Dhabi' },
];

const ACTIVITIES = [
  { slug: 'hiking',       zh: '徒步',     en: 'Hiking',       emoji: '🥾', desc_zh: '探索城市周边的山野步道', desc_en: 'Explore trails and nature around the city' },
  { slug: 'dining',       zh: '约饭',     en: 'Dining',       emoji: '🍽️', desc_zh: '发现新餐厅，享受美食', desc_en: 'Discover new restaurants and enjoy great food' },
  { slug: 'coffee',       zh: '喝咖啡',   en: 'Coffee',       emoji: '☕', desc_zh: '找个安静的咖啡馆聊聊天', desc_en: 'Find a cozy café for a great conversation' },
  { slug: 'gym',          zh: '健身',     en: 'Gym',          emoji: '💪', desc_zh: '一起撸铁，互相激励', desc_en: 'Work out together and stay motivated' },
  { slug: 'running',      zh: '跑步',     en: 'Running',      emoji: '🏃', desc_zh: '结伴晨跑夜跑更有动力', desc_en: 'Find a running buddy for daily jogs' },
  { slug: 'board-game',   zh: '桌游',     en: 'Board Game',   emoji: '🎲', desc_zh: '狼人杀、剧本杀、策略游戏', desc_en: 'Board games, Werewolf, and strategy nights' },
  { slug: 'movie',        zh: '看电影',   en: 'Movie',        emoji: '🎬', desc_zh: '一起看新片，映后讨论', desc_en: 'Watch new releases and discuss after' },
  { slug: 'exhibition',   zh: '看展',     en: 'Exhibition',   emoji: '🎨', desc_zh: '美术馆、博物馆一起逛', desc_en: 'Visit museums and art galleries together' },
  { slug: 'photography',  zh: '摄影',     en: 'Photography',  emoji: '📸', desc_zh: '城市街拍、风景摄影搭子', desc_en: 'Street and landscape photography outings' },
  { slug: 'travel',       zh: '旅行',     en: 'Travel',       emoji: '✈️', desc_zh: '周末短途或长途旅行同伴', desc_en: 'Weekend getaways and travel companions' },
  { slug: 'language',     zh: '语言交换', en: 'Language Exchange', emoji: '🗣️', desc_zh: '互教语言，共同进步', desc_en: 'Practice languages with native speakers' },
  { slug: 'study',        zh: '自习',     en: 'Study',        emoji: '📚', desc_zh: '图书馆、自习室结伴学习', desc_en: 'Study sessions at libraries or cafés' },
  { slug: 'music',        zh: '音乐',     en: 'Music',        emoji: '🎵', desc_zh: '一起玩乐器、听演出', desc_en: 'Jam sessions and live music events' },
  { slug: 'cooking',      zh: '做饭',     en: 'Cooking',      emoji: '🧑‍🍳', desc_zh: '学做新菜、分享拿手好菜', desc_en: 'Cook together and share recipes' },
  { slug: 'cycling',      zh: '骑行',     en: 'Cycling',      emoji: '🚴', desc_zh: '城市骑行或郊外越野', desc_en: 'City rides and countryside cycling' },
  { slug: 'swimming',     zh: '游泳',     en: 'Swimming',     emoji: '🏊', desc_zh: '泳池搭子，互相监督', desc_en: 'Swim laps together and stay consistent' },
  { slug: 'yoga',         zh: '瑜伽',     en: 'Yoga',         emoji: '🧘', desc_zh: '晨练瑜伽，身心放松', desc_en: 'Morning yoga and mindfulness sessions' },
  { slug: 'karaoke',      zh: 'K歌',     en: 'Karaoke',      emoji: '🎤', desc_zh: 'KTV 唱歌搭子', desc_en: 'Karaoke nights with new friends' },
  { slug: 'badminton',    zh: '羽毛球',   en: 'Badminton',    emoji: '🏸', desc_zh: '找个水平相当的球友', desc_en: 'Find a badminton partner at your level' },
  { slug: 'pet-walking',  zh: '遛宠物',   en: 'Pet Walking',  emoji: '🐕', desc_zh: '带上毛孩子一起社交', desc_en: 'Walk pets and socialize with fellow owners' },
];

const DOMAIN = 'https://dazi.app';

// ─── 模板 ────────────────────────────────────────────

function generatePage(city, activity) {
  const titleZh = `在${city.zh}找${activity.zh}搭子`;
  const titleEn = `Find a ${activity.en} Partner in ${city.en}`;
  const descZh = `搭子App帮你在${city.zh}找到志同道合的${activity.zh}伙伴。${activity.desc_zh}，不再一个人！`;
  const descEn = `Dazi App helps you find ${activity.en.toLowerCase()} partners in ${city.en}. ${activity.desc_en}. Never go alone!`;
  const url = `${DOMAIN}/find/${activity.slug}-partner-in-${city.slug}`;
  const canonical = `/find/${activity.slug}-partner-in-${city.slug}`;

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>${titleZh} | 搭子 Dazi</title>
<meta name="description" content="${descZh}">
<meta name="keywords" content="${activity.zh},${city.zh},搭子,找伙伴,${activity.en},${city.en},partner,buddy">
<link rel="canonical" href="${url}">
<meta property="og:title" content="${titleZh} | 搭子">
<meta property="og:description" content="${descZh}">
<meta property="og:url" content="${url}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="搭子 Dazi">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${titleZh}">
<meta name="twitter:description" content="${descZh}">
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": "${titleZh}",
  "description": "${descZh}",
  "url": "${url}",
  "inLanguage": ["zh-CN", "en"],
  "about": {
    "@type": "Thing",
    "name": "${activity.en}",
    "description": "${activity.desc_en}"
  },
  "spatialCoverage": {
    "@type": "Place",
    "name": "${city.en}",
    "address": { "@type": "PostalAddress", "addressLocality": "${city.en}" }
  },
  "publisher": {
    "@type": "Organization",
    "name": "搭子 Dazi",
    "url": "${DOMAIN}"
  }
}
</script>
<style>
*{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent}
html,body{font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif;background:#fff;color:#1a1a1a;line-height:1.6}
.hero{min-height:60vh;background:linear-gradient(160deg,#ff8a65 0%,#ff6b9d 50%,#a855f7 100%);color:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:60px 24px 40px;text-align:center}
.emoji-hero{font-size:72px;margin-bottom:16px}
h1{font-size:28px;font-weight:800;margin-bottom:8px;text-shadow:0 2px 8px rgba(0,0,0,.12)}
.subtitle{font-size:16px;opacity:.92;margin-bottom:32px;max-width:400px}
.cta{display:inline-block;background:#fff;color:#ff6b9d;padding:14px 40px;border-radius:999px;font-size:16px;font-weight:700;text-decoration:none;box-shadow:0 4px 20px rgba(0,0,0,.12);transition:transform .15s}
.cta:active{transform:scale(.97)}
.section{max-width:640px;margin:0 auto;padding:40px 24px}
h2{font-size:22px;font-weight:700;margin-bottom:16px;color:#1a1a1a}
.steps{display:grid;gap:16px;margin-bottom:32px}
.step{display:flex;gap:16px;align-items:flex-start;background:#fafafa;padding:20px;border-radius:16px}
.step-num{width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg,#ff8a65,#ff6b9d);color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:16px;flex-shrink:0}
.step-text h3{font-size:16px;font-weight:600;margin-bottom:4px}
.step-text p{font-size:14px;color:#666}
.features{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:16px;margin-bottom:32px}
.feat{text-align:center;padding:24px 16px;background:#fafafa;border-radius:16px}
.feat-icon{font-size:32px;margin-bottom:8px}
.feat-title{font-weight:600;font-size:14px;margin-bottom:4px}
.feat-desc{font-size:12px;color:#888}
.nearby{margin-top:24px}
.nearby-list{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.nearby-link{display:inline-block;padding:6px 14px;background:#fff0f3;color:#ff6b9d;border-radius:999px;font-size:13px;text-decoration:none;font-weight:500;transition:background .15s}
.nearby-link:hover{background:#ffe0e8}
.bottom-cta{text-align:center;padding:48px 24px;background:linear-gradient(160deg,#ff8a65 0%,#ff6b9d 50%,#a855f7 100%)}
.bottom-cta h2{color:#fff;margin-bottom:12px}
.bottom-cta p{color:rgba(255,255,255,.9);margin-bottom:24px;font-size:15px}
footer{padding:24px;text-align:center;color:#888;font-size:12px;background:#fafafa}
footer a{color:#888;text-decoration:none;margin:0 8px}
@media(min-width:768px){h1{font-size:36px}.emoji-hero{font-size:96px}}
</style>
</head>
<body>

<header class="hero">
  <div class="emoji-hero">${activity.emoji}</div>
  <h1>${titleZh}</h1>
  <p class="subtitle">${titleEn}</p>
  <p class="subtitle">${descZh}</p>
  <a href="/" class="cta">立即下载搭子 App</a>
</header>

<section class="section">
  <h2>${activity.emoji} 为什么在${city.zh}找${activity.zh}搭子？</h2>
  <p style="color:#555;margin-bottom:24px">${activity.desc_zh}。在${city.zh}，越来越多的年轻人选择用搭子 App 找到志同道合的伙伴，一起${activity.zh}。无论你是刚搬到${city.zh}还是想认识新朋友，搭子都能帮你快速找到合适的${activity.zh}同伴。</p>

  <h2>🚀 三步找到你的${activity.zh}搭子</h2>
  <div class="steps">
    <div class="step">
      <div class="step-num">1</div>
      <div class="step-text">
        <h3>发布活动</h3>
        <p>选择"${activity.zh}"分类，填写时间地点，30 秒发布一条${activity.zh}邀约</p>
      </div>
    </div>
    <div class="step">
      <div class="step-num">2</div>
      <div class="step-text">
        <h3>智能匹配</h3>
        <p>AI 根据兴趣、位置和空闲时间，为你推荐${city.zh}附近最合适的${activity.zh}搭子</p>
      </div>
    </div>
    <div class="step">
      <div class="step-num">3</div>
      <div class="step-text">
        <h3>见面出发</h3>
        <p>双方确认后，押金保障到场，不放鸽子。见完面还能互评积累信任分</p>
      </div>
    </div>
  </div>

  <h2>✨ 搭子 App 核心特色</h2>
  <div class="features">
    <div class="feat">
      <div class="feat-icon">🎯</div>
      <div class="feat-title">AI 智能匹配</div>
      <div class="feat-desc">基于兴趣和位置精准推荐</div>
    </div>
    <div class="feat">
      <div class="feat-icon">🛡️</div>
      <div class="feat-title">反鸽子机制</div>
      <div class="feat-desc">押金 + 签到，确保到场</div>
    </div>
    <div class="feat">
      <div class="feat-icon">⭐</div>
      <div class="feat-title">行为信任分</div>
      <div class="feat-desc">真实评价，靠谱可见</div>
    </div>
    <div class="feat">
      <div class="feat-icon">🌍</div>
      <div class="feat-title">7 种语言</div>
      <div class="feat-desc">中英日韩西法德全覆盖</div>
    </div>
  </div>
</section>

<section class="section nearby">
  <h2>🏙️ ${city.zh}热门搭子活动</h2>
  <div class="nearby-list" id="activity-links"></div>

  <h2 style="margin-top:32px">🌏 更多城市</h2>
  <div class="nearby-list" id="city-links"></div>
</section>

<section class="bottom-cta">
  <h2>在${city.zh}找${activity.zh}搭子</h2>
  <p>已有数万用户在使用搭子 App 结识新朋友</p>
  <a href="/" class="cta">免费下载</a>
</section>

<footer>
  <div>&copy; 2026 搭子 App &middot; 让每次见面都值得</div>
  <div style="margin-top:8px">
    <a href="/privacy.html">隐私政策</a>&middot;
    <a href="/terms.html">用户协议</a>&middot;
    <a href="mailto:hello@dazi.app">联系我们</a>
  </div>
</footer>

<script>
(function(){
  var activities = ${JSON.stringify(ACTIVITIES.map(a => ({ slug: a.slug, zh: a.zh, emoji: a.emoji })))};
  var cities = ${JSON.stringify(CITIES.map(c => ({ slug: c.slug, zh: c.zh })))};
  var curActivity = '${activity.slug}';
  var curCity = '${city.slug}';

  var actEl = document.getElementById('activity-links');
  activities.forEach(function(a) {
    var el = document.createElement('a');
    el.className = 'nearby-link';
    el.href = '/find/' + a.slug + '-partner-in-' + curCity;
    el.textContent = a.emoji + ' ' + a.zh;
    if (a.slug === curActivity) el.style.background = '#ff6b9d', el.style.color = '#fff';
    actEl.appendChild(el);
  });

  var cityEl = document.getElementById('city-links');
  cities.forEach(function(c) {
    var el = document.createElement('a');
    el.className = 'nearby-link';
    el.href = '/find/' + curActivity + '-partner-in-' + c.slug;
    el.textContent = c.zh;
    if (c.slug === curCity) el.style.background = '#ff6b9d', el.style.color = '#fff';
    cityEl.appendChild(el);
  });
})();
</script>
</body>
</html>`;
}

// ─── sitemap.xml ─────────────────────────────────────

function generateSitemap(pages) {
  const urls = [
    `  <url><loc>${DOMAIN}/</loc><changefreq>daily</changefreq><priority>1.0</priority></url>`,
    `  <url><loc>${DOMAIN}/privacy.html</loc><changefreq>monthly</changefreq><priority>0.3</priority></url>`,
    `  <url><loc>${DOMAIN}/terms.html</loc><changefreq>monthly</changefreq><priority>0.3</priority></url>`,
    ...pages.map(p =>
      `  <url><loc>${DOMAIN}/find/${p}</loc><changefreq>weekly</changefreq><priority>0.6</priority></url>`
    ),
  ];

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join('\n')}
</urlset>`;
}

// ─── robots.txt ──────────────────────────────────────

function generateRobots() {
  return `User-agent: *
Allow: /
Sitemap: ${DOMAIN}/sitemap.xml
`;
}

// ─── 主程序 ──────────────────────────────────────────

function main() {
  const outDir = path.resolve(__dirname, '..', 'public', 'find');
  const publicDir = path.resolve(__dirname, '..', 'public');

  // 创建输出目录
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  const pageSlugs = [];
  let count = 0;

  for (const city of CITIES) {
    for (const activity of ACTIVITIES) {
      const slug = `${activity.slug}-partner-in-${city.slug}`;
      const html = generatePage(city, activity);
      fs.writeFileSync(path.join(outDir, `${slug}.html`), html, 'utf8');
      pageSlugs.push(slug);
      count++;
    }
  }

  // 生成 sitemap.xml
  const sitemap = generateSitemap(pageSlugs);
  fs.writeFileSync(path.join(publicDir, 'sitemap.xml'), sitemap, 'utf8');

  // 生成 robots.txt
  const robots = generateRobots();
  fs.writeFileSync(path.join(publicDir, 'robots.txt'), robots, 'utf8');

  console.log(`Generated ${count} landing pages in public/find/`);
  console.log(`Generated sitemap.xml (${pageSlugs.length + 3} URLs)`);
  console.log(`Generated robots.txt`);
}

main();
