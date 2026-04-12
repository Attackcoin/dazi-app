import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// 隐私设置 —— 展示粒度开关 + 黑名单入口。
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  final Map<String, bool> _prefs = {
    'showAge': true,
    'showCity': true,
    'allowSearchByPhone': false,
    'hideFromNearby': false,
  };
  bool _initialized = false;
  bool _saving = false;

  static const _items = [
    ('showAge', '展示年龄', '在个人主页显示年龄'),
    ('showCity', '展示城市', '在个人主页显示所在城市'),
    ('allowSearchByPhone', '允许通过手机号搜索', '他人可用手机号找到你'),
    ('hideFromNearby', '不在附近列表显示', '隐藏自己的广场动态'),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).setPrivacyPrefs(_prefs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final user = ref.watch(currentAppUserProvider).valueOrNull;
    if (user != null && !_initialized) {
      for (final entry in user.privacyPrefs.entries) {
        _prefs[entry.key] = entry.value;
      }
      _initialized = true;
    }

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('隐私设置'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space16,
            vertical: Spacing.space8,
          ),
          children: [
            ..._items.map((item) {
              final (key, title, subtitle) = item;
              return Padding(
                padding: const EdgeInsets.only(bottom: Spacing.space8),
                child: GlassCard(
                  level: 1,
                  child: SwitchListTile(
                    title: Text(
                      title,
                      style: TextStyle(color: gt.colors.textPrimary),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: gt.colors.textSecondary,
                      ),
                    ),
                    value: _prefs[key] ?? false,
                    activeColor: gt.colors.primary,
                    onChanged: (v) => setState(() => _prefs[key] = v),
                  ),
                ),
              );
            }),
            const SizedBox(height: Spacing.space8),
            GlassCard(
              level: 1,
              onTap: () => context.push('/settings/blocked'),
              child: ListTile(
                leading: Icon(Icons.block, color: gt.colors.textSecondary),
                title: Text(
                  '黑名单',
                  style: TextStyle(color: gt.colors.textPrimary),
                ),
                subtitle: Text(
                  '管理你屏蔽的用户',
                  style: TextStyle(
                    fontSize: 12,
                    color: gt.colors.textSecondary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: gt.colors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
