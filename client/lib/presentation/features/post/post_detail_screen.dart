import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/post_repository.dart';

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postByIdProvider(postId));

    return Scaffold(
      body: postAsync.when(
        data: (post) => post == null ? _notFound(context) : _buildContent(context, post),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
      bottomNavigationBar: postAsync.valueOrNull == null
          ? null
          : _buildBottomBar(context, postAsync.value!),
    );
  }

  Widget _notFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('帖子不存在或已删除')),
    );
  }

  Widget _buildContent(BuildContext context, Post post) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          leading: CircleAvatar(
            backgroundColor: Colors.black38,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
              onPressed: () => context.pop(),
            ),
          ),
          actions: [
            CircleAvatar(
              backgroundColor: Colors.black38,
              child: IconButton(
                icon: const Icon(Icons.ios_share,
                    color: Colors.white, size: 18),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 16),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: post.images.isEmpty
                ? Container(
                    decoration:
                        const BoxDecoration(gradient: AppColors.heroGradient),
                  )
                : CachedNetworkImage(
                    imageUrl: post.images.first,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    post.category,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                _buildInfoBox(post),
                const SizedBox(height: 24),
                if (post.description.isNotEmpty) ...[
                  Text(
                    '活动介绍',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(Post post) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.schedule,
            '时间',
            post.time == null
                ? '待定'
                : DateFormat('yyyy年M月d日 HH:mm').format(post.time!),
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.location_on_outlined,
            '地点',
            post.location?.name ?? '待定',
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.payments_outlined,
            '费用',
            post.depositAmount > 0
                ? '${post.costType.label} · 押金 ¥${post.depositAmount}'
                : post.costType.label,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.group_outlined,
            '人数',
            '${post.acceptedCount}/${post.totalSlots} 人',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, Post post) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton.outlined(
              onPressed: () {},
              icon: const Icon(Icons.favorite_border),
              style: IconButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: post.isFull ? null : () {},
                child: Text(post.isFull ? '加入候补' : '立即申请'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
