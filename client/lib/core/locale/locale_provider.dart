import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户选择的 locale。null 表示跟随系统。
///
/// 遵循 SD-1：只用 StateProvider，不用 Notifier。
final localeProvider = StateProvider<Locale?>((ref) => null);

/// 持久化 + 恢复 locale 选择的辅助工具。
class LocalePersistence {
  static const _key = 'app_locale';

  /// 从 SharedPreferences 加载用户上次选择的 locale。
  /// 返回 null 表示未设置（跟随系统）。
  static Future<Locale?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  /// 持久化用户选择。传 null 表示"跟随系统"。
  static Future<void> save(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}
