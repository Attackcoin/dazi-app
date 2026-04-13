import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// 通知设置 —— 开关各类推送。
class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  final Map<String, bool> _prefs = {
    'newApplication': true,
    'applicationAccepted': true,
    'newMessage': true,
    'checkinReminder': true,
    'reviewReceived': true,
    'systemAnnouncement': true,
  };
  bool _initialized = false;
  bool _saving = false;

  static const _items = [
    ('newApplication', '新申请', '有人申请你的搭子时'),
    ('applicationAccepted', '申请被接受', '你申请的搭子被接受时'),
    ('newMessage', '新消息', '收到聊天消息时'),
    ('checkinReminder', '签到提醒', '活动开始前提醒签到'),
    ('reviewReceived', '收到评价', '对方给你写评价时'),
    ('systemAnnouncement', '系统公告', '平台重要通知'),
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).setNotificationsPrefs(_prefs);
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
      for (final entry in user.notificationsPrefs.entries) {
        _prefs[entry.key] = entry.value;
      }
      _initialized = true;
    }

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('通知设置'),
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
        body: ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.space16,
            vertical: Spacing.space8,
          ),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: Spacing.space8),
          itemBuilder: (_, i) {
            final (key, title, subtitle) = _items[i];
            return GlassCard(
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
                value: _prefs[key] ?? true,
                activeColor: gt.colors.primary,
                onChanged: (v) => setState(() => _prefs[key] = v),
              ),
            );
          },
        ),
      ),
    );
  }
}
