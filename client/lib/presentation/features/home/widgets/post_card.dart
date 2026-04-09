import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImage(),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryTag(),
                  const SizedBox(height: 8),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  _buildMetaRow(Icons.schedule, _formatTime(post.time)),
                  const SizedBox(height: 4),
                  _buildMetaRow(
                    Icons.location_on_outlined,
                    post.location?.name ?? '地点待定',
                  ),
                  const SizedBox(height: 12),
                  _SlotsBar(post: post),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = post.images.isNotEmpty ? post.images.first : null;
    if (url == null) {
      return Container(
        height: 140,
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white54, size: 40),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      height: 140,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: AppColors.surfaceAlt),
      errorWidget: (_, __, ___) => Container(
        height: 140,
        color: AppColors.surfaceAlt,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }

  Widget _buildCategoryTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        post.category,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '时间待定';
    return DateFormat('M月d日 HH:mm').format(time);
  }
}

/// 人数进度条，同时显示男女配额（如果设置了）。
class _SlotsBar extends StatelessWidget {
  const _SlotsBar({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.surfaceAlt),
                FractionallySizedBox(
                  widthFactor: post.slotProgress,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      gradient: AppColors.ctaGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${post.acceptedCount}/${post.totalSlots}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
