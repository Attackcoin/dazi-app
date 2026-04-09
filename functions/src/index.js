/**
 * 搭子 App — Firebase Cloud Functions
 * 入口文件：统一导出所有功能模块
 */

const admin = require('firebase-admin');
admin.initializeApp();

// 导出各功能模块
module.exports = {
  ...require('./ai'),
  ...require('./antiGhosting'),
  ...require('./applications'),
  ...require('./deposits'),
  ...require('./notifications'),
  ...require('./algoliaSync'),
};
