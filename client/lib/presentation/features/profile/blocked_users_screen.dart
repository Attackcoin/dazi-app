import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// 黑名单页 —— 显示被屏蔽的用户，支持解除屏蔽。
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('黑名单')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (user) {
          if (user == null) return const Center(child: Text('未登录'));
          final blocked = user.blockedUsers;
          if (blocked.isEmpty) {
            return const Center(
              child: Text(
                '还没有屏蔽任何用户',
                style: TextStyle(color: AppColors.textTertiary),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: profiles.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = profiles[i];
                  final name = (p['name'] as String?) ?? '未知';
                  final avatar = (p['avatar'] as String?) ?? '';
                  final uid = p['id'] as String;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.surfaceAlt,
                      backgroundImage: avatar.isNotEmpty
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person,
                              color: AppColors.textSecondary)
                          : null,
                    ),
                    title: Text(name),
                    trailing: TextButton(
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
                      child: const Text('解除'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
