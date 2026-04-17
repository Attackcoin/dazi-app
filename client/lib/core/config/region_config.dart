import 'dart:ui';

/// Firebase Functions 多地区部署配置（T5-13）。
///
/// 海外用户走 us-central1，国内用户走 asia-southeast1，
/// 减少 Cloud Functions 调用延迟（Firestore 全球单实例，不影响数据一致性）。
class RegionConfig {
  RegionConfig._();

  static const asiaSoutheast1 = 'asia-southeast1';
  static const usCentral1 = 'us-central1';

  /// 根据系统 locale 推断最佳 Functions region。
  ///
  /// 中文用户 → asia-southeast1
  /// 其他 → us-central1（全球延迟最低的默认选项）
  static String resolveFunctionsRegion() {
    final locale = PlatformDispatcher.instance.locale;

    // 中文区域 → 亚洲节点
    if (locale.languageCode == 'zh' ||
        locale.countryCode == 'CN' ||
        locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.countryCode == 'SG') {
      return asiaSoutheast1;
    }

    // 日韩东南亚 → 也走亚洲节点
    if ({'ja', 'ko', 'th', 'vi', 'id', 'ms'}.contains(locale.languageCode)) {
      return asiaSoutheast1;
    }

    // 其他 → 美国中部
    return usCentral1;
  }
}
