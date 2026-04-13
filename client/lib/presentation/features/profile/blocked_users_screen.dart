import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// 黑名单页 —— 显示被屏蔽的用户，支持解除屏蔽。
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final userAsync = ref.watch(currentAppUserProvider);

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('黑名单'),
        ),
        body: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              '加载失败：$e',
              style: TextStyle(color: gt.colors.textSecondary),
            ),
          ),
          data: (user) {
            if (user == null) {
              return Center(
                child: Text(
                  '未登录',
                  style: TextStyle(color: gt.colors.textSecondary),
                ),
              );
            }
            final blocked = user.blockedUsers;
            if (blocked.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block,
                      size: 48,
                      color: gt.colors.textTertiary,
                    ),
                    const SizedBox(height: Spacing.space12),
                    Text(
                      '还没有屏蔽任何用户',
                      style: TextStyle(color: gt.colors.textTertiary),
                    ),
                  ],
                ),
              );
            }
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref
                  .read(userRepositoryProvider)
                  .watchBlockedProfiles(blocked),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profiles = snap.data!;
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space16,
                    vertical: Spacing.space8,
                  ),
                  itemCount: profiles.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Spacing.space8),
                  itemBuilder: (_, i) {
                    final p = profiles[i];
                    final name = (p['name'] as String?) ?? '未知';
                    final avatar = (p['avatar'] as String?) ?? '';
                    final uid = p['id'] as String;
                    return GlassCard(
                      level: 1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.space12,
                        vertical: Spacing.space8,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: gt.colors.glassL2Bg,
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? Icon(
                                    Icons.person,
                                    color: gt.colors.textSecondary,
                                  )
                                : null,
                          ),
                          const SizedBox(width: Spacing.space12),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: gt.colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          GlassButton(
                            label: '解除',
                            variant: GlassButtonVariant.danger,
                            onPressed: () async {
                              try {
                                await ref
                                    .read(userRepositoryProvider)
                                    .unblockUser(uid);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已解除屏蔽')),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('操作失败：$e')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
