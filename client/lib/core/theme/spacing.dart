// client/lib/core/theme/spacing.dart

/// 搭子 App 间距系统。所有间距必须使用这些 token，禁止硬编码数值。
class Spacing {
  Spacing._();

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
}

/// 搭子 App 圆角系统。
class Radii {
  Radii._();

  static const double card = 20;
  static const double button = 16;
  static const double input = 14;
  static const double pill = 12;
  static const double sheet = 24;
  // 头像用 50%，在代码中用 CircleAvatar 或 borderRadius: height/2
}
