# H5 落地页部署指南

`public/` 目录包含搭子 App 的分享落地页，部署在 Firebase Hosting。

## 文件结构

```
public/
├── index.html      # 首页 / 下载页（根域名访问）
├── post.html       # 帖子分享页（/p/:postId 访问）
├── privacy.html    # 隐私政策（App Store 审核必须）
└── terms.html      # 用户协议
```

## 路由规则（firebase.json）

| 路径 | 落地页 |
|-----|-------|
| `/` | `index.html` |
| `/p/:postId` | `post.html`（读取 Firestore 展示帖子详情） |
| `/post/:postId` | `post.html`（备用路径） |
| `/privacy.html` | 隐私政策 |
| `/terms.html` | 用户协议 |

## 部署前必做

### 1. 替换 Firebase Web 配置

编辑 `public/post.html`，找到 `firebaseConfig` 对象，替换为真实配置：

1. Firebase Console → 项目设置 → 常规 → 你的应用 → **添加应用** → Web
2. 应用昵称填 `dazi-h5`
3. 复制生成的 `firebaseConfig`
4. 粘贴到 `post.html` 顶部

```javascript
const firebaseConfig = {
  apiKey: "AIzaSy...",
  authDomain: "dazi-dev.firebaseapp.com",
  projectId: "dazi-dev",
  storageBucket: "dazi-dev.appspot.com",
  messagingSenderId: "...",
  appId: "..."
};
```

### 2. 替换应用商店链接

编辑 `public/index.html` 底部脚本：

```javascript
iosBtn.href = 'https://apps.apple.com/app/dazi';           // 上架后替换
androidBtn.href = 'https://play.google.com/store/...';     // 上架后替换
```

上架前可以先跳转到内测邀请页或邮件订阅页。

### 3. 配置 Firestore 读取权限

`post.html` 通过 Web SDK 读取 `posts` 集合，需要确认安全规则允许匿名读取：

```javascript
// firestore.rules
match /posts/{postId} {
  allow read: if true;  // 分享页需要匿名可读
}
```

已在当前规则中生效（规则要求 `request.auth != null`，需要调整）。

⚠️ **建议**：为分享页创建专用的 Cloud Function HTTPS 端点，返回脱敏数据，避免前端直连 Firestore。这样可以：
- 不暴露 Firestore 配置
- 过滤敏感字段（如申请者列表）
- 记录分享点击量

## 部署命令

```bash
cd /c/Users/CRISP/OneDrive/文档/dazi-app

# 首次部署
firebase deploy --only hosting

# 仅部署 hosting
firebase deploy --only hosting --project dazi-dev
```

部署成功后会显示两个 URL：
- `https://dazi-dev.web.app`
- `https://dazi-dev.firebaseapp.com`

## 绑定自定义域名（可选）

1. Firebase Console → Hosting → **添加自定义域名**
2. 输入 `dazi.app` 或你拥有的域名
3. 按提示添加 DNS TXT 记录验证所有权
4. Firebase 自动签发 Let's Encrypt 证书
5. 完成后 `https://dazi.app` 和 `https://www.dazi.app` 都会指向 hosting

## 测试链接

部署后，分享链接格式为：
```
https://dazi-dev.web.app/p/POST_ID
```

用户点击后：
1. 浏览器打开落地页
2. 尝试通过 `dazi://post/POST_ID` scheme 拉起 App
3. 拉起失败则引导到应用商店下载
