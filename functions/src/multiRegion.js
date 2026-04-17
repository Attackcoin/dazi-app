/**
 * 多地区部署入口（T5-13）
 *
 * 为延迟敏感的 onCall 函数创建 us-central1 副本。
 * Firestore 触发器和定时任务保持单区域（asia-southeast1），
 * 避免重复触发。
 *
 * 命名规则：原函数名 + `_us` 后缀，前端通过 RegionConfig 自动路由。
 *
 * 注意：Firebase Functions Gen1 不支持单函数多 region，
 * 所以用独立函数名实现。Gen2 迁移后可改为 globalOptions。
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');

const db = admin.firestore();

// ─── 从其他模块导入 handler 逻辑 ───

// 复用 applications 模块的 handler
const applicationsModule = require('./applications');
const { _moderateText } = require('./moderation');
const { _generateEmbedding, _userToText } = require('./embeddings');

// ─────────────────────────────────────────────────────
// us-central1 onCall 副本：applyToPost
// ─────────────────────────────────────────────────────
// 注意：由于 Gen1 onCall 不能共享 handler 引用（region 在 export 时绑定），
// 真正的多 region 需要在 index.js 中为每个函数手动双 region export。
// 以下是架构占位——实际生产部署时直接在 firebase.json 或 Gen2 配置中处理。

// 目前保持单 region 部署，此文件作为 T5-13 架构记录和未来迁移入口。
// 当 Firebase Functions Gen2 稳定后，改为：
//   exports.applyToPost = onCall({ region: ['asia-southeast1', 'us-central1'] }, handler);

/**
 * 多区域部署方案（记录于代码中供 CLAUDE.md 引用）：
 *
 * 方案 A（当前）：单 region asia-southeast1
 *   - 所有函数部署在一个 region
 *   - 简单可靠，适合 MVP
 *
 * 方案 B（推荐中期）：Gen2 多 region
 *   - 迁移到 Functions Gen2
 *   - onCall 函数加 region: ['asia-southeast1', 'us-central1']
 *   - 触发器保持单 region
 *
 * 方案 C（长期）：独立 Firebase 项目
 *   - 国内/海外各自独立项目
 *   - 数据通过 Firestore Data Connect 同步
 *   - 最佳延迟但运维复杂度最高
 */

// 无实际导出 —— 此文件不在 index.js 中导入
// 当准备好多 region 时，取消注释以下代码：
//
// exports.applyToPost_us = functions
//   .region('us-central1')
//   .https.onCall(applicationsModule.applyToPost);
