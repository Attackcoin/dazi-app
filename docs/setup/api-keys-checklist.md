# API Keys 申请清单

> 按优先级排序。每项都包含：申请地址、获取什么、花费、配置位置。
> 完成一项就在前面打勾。

---

## 🟢 免费 / 必须（上线前必须完成）

### ☐ 1. Google Maps API Key

**用途**：地图显示、地点选择、距离计算
**地址**：https://console.cloud.google.com
**花费**：免费（每月 $200 额度，搭子这种用量远用不完）

**操作步骤**：
1. 登录 Google Cloud Console → 创建项目 `dazi-app`
2. 左侧菜单 → **APIs & Services** → **Library**
3. 依次启用以下 API：
   - `Maps SDK for Android`
   - `Maps SDK for iOS`
   - `Places API`
   - `Geocoding API`
4. **Credentials** → **Create Credentials** → **API Key**
5. 复制生成的 Key
6. （推荐）点击 Key → **Restrict key** → 限制为以上 4 个 API，避免被滥用

**配置位置**：
- Firebase Remote Config → `google_maps_api_key`（前端读取）
- 或 FlutterFlow → Settings → Project Dependencies → Google Maps API Key

---

### ☐ 2. Algolia 搜索

**用途**：中文全文搜索（Firestore 原生不支持中文分词）
**地址**：https://www.algolia.com
**花费**：免费套餐每月 10,000 次搜索 + 10,000 条记录，MVP 够用

**操作步骤**：
1. 注册账号 → 创建 Application：`dazi-search`
2. 选择区域：**Hong Kong (aps-1)** 或 **Singapore (aps-2)**（国内访问延迟低）
3. 进入 Application → **API Keys** 标签页
4. 复制三个 Key：
   - `Application ID`
   - `Admin API Key`（⚠️ 机密，只在 Firebase Functions 使用）
   - `Search-Only API Key`（前端可用）
5. **Indices** → **Create Index** → 名字填 `posts`
6. 进入 `posts` 索引 → **Configuration**：
   - **Searchable attributes**：`title`, `description`, `locationName`, `category`
   - **Attributes for faceting**：`city`, `status`, `costType`, `isSocialAnxietyFriendly`
   - **Custom Ranking**：`desc(createdAt)`
   - **Language**：Chinese (Simplified)

**配置位置**：
```bash
cd functions
firebase functions:config:set \
  algolia.app_id="YOUR_APP_ID" \
  algolia.admin_key="YOUR_ADMIN_KEY"

# 或编辑 functions/.env
ALGOLIA_APP_ID=YOUR_APP_ID
ALGOLIA_ADMIN_KEY=YOUR_ADMIN_KEY
```

然后部署：`firebase deploy --only functions`

**验证**：在 Firestore posts 集合手动新增一条记录 → 几秒后应出现在 Algolia `posts` 索引中

---

### ☐ 3. Claude API (Anthropic)

**状态**：✅ 已配置（见 `functions/.env`）

---

## 🟡 付费 / 上线前必须

### ☐ 4. 阿里云实人认证

**用途**：身份证 + 活体验证
**地址**：https://www.aliyun.com
**花费**：按调用量，约 ¥1.5/次

**前置条件**：**企业实名认证**（个人账号不能开通）

**操作步骤**：
1. 注册阿里云企业账号（需要营业执照）
2. 产品 → **实人认证** → 开通
3. 选择方案：**实人认证标准版**（含身份证 OCR + 活体检测）
4. **AccessKey 管理** → 创建 AccessKey（建议用 RAM 子账号，只授权实人认证权限）
5. 记录：`AccessKey ID` / `AccessKey Secret`

**配置位置**：`functions/.env`
```
ALIYUN_ACCESS_KEY_ID=...
ALIYUN_ACCESS_KEY_SECRET=...
ALIYUN_REGION=cn-hangzhou
```

---

### ☐ 5. 微信支付 + 支付宝担保交易

**用途**：押金冻结/释放
**花费**：微信 ¥300 认证费，费率 0.6%
**前置条件**：**营业执照 + 对公账户**

**微信支付操作步骤**：
1. https://pay.weixin.qq.com → 商户入驻
2. 提交营业执照、法人身份证、对公账户
3. 审核通过（3-5 工作日）→ 获得 `MCH_ID`（商户号）
4. 设置 API 密钥：商户平台 → **账户中心** → **API 安全** → 设置 APIv3 密钥
5. 下载商户证书 `apiclient_cert.pem`

**支付宝操作步骤**：
1. https://open.alipay.com → 开放平台注册
2. 创建应用：**网页/移动应用**
3. 功能列表中添加：**手机网站支付**、**资金授权**
4. 生成 RSA2 密钥对（上传公钥给支付宝）
5. 记录：`APP_ID` / `私钥` / `支付宝公钥`

**配置位置**：`functions/.env`
```
WECHAT_PAY_APP_ID=...
WECHAT_PAY_MCH_ID=...
WECHAT_PAY_API_KEY=...

ALIPAY_APP_ID=...
ALIPAY_PRIVATE_KEY=...
ALIPAY_PUBLIC_KEY=...
```

---

## 🔵 可选 / 后期

### ☐ 6. 芝麻信用 API

**用途**：信用分 ≥ 750 的用户押金减免
**地址**：https://b.zmxy.com.cn
**门槛**：需已接入支付宝的商户

### ☐ 7. Firebase Dynamic Links

**状态**：⚠️ Google 已宣布 2025-08 下线，改用：
- iOS：Universal Links（在 `apple-app-site-association` 文件配置）
- Android：App Links（在 `assetlinks.json` 配置）
- 深度链接方案已内置在 `public/post.html` 使用 `dazi://` scheme

---

## 完成后的验证清单

- [ ] Google Maps 在 Web 测试页能加载地图
- [ ] Algolia 搜索 "咖啡" 能返回结果
- [ ] 阿里云实人认证 demo 能通过活体检测
- [ ] 微信支付沙箱环境成功冻结 ¥1
- [ ] 支付宝沙箱环境成功授权

**全部绿灯后才能进入 TestFlight 内测阶段。**
