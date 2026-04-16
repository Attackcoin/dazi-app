import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/avatar_stack.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/pill_tag.dart';
import '../../../../data/models/post.dart';

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, this.onTap});

  final Post post;
  final VoidCallback? onTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.97);
  void _onTapUp(TapUpDetails _) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final post = widget.post;

    final semanticsLabel = [
      post.category,
      post.title,
      _formatTime(post.time),
      post.location?.name ?? '地点待定',
      '已报名 ${post.acceptedCount} / ${post.totalSlots} 人',
    ].join('，');

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap != null ? _onTapDown : null,
        onTapUp: widget.onTap != null ? _onTapUp : null,
        onTapCancel: widget.onTap != null ? _onTapCancel : null,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: GlassCard(
            level: 1,
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Publisher row
                _buildPublisherRow(gt, post),
                // Image
                _buildImage(gt, post),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category tag
                      PillTag(label: post.category),
                      const SizedBox(height: Spacing.space8),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: gt.colors.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      _buildMetaRow(
                          gt, Icons.schedule, _formatTime(post.time)),
                      const SizedBox(height: Spacing.space4),
                      _buildMetaRow(
                        gt,
                        Icons.location_on_outlined,
                        post.location?.name ?? '地点待定',
                      ),
                      const SizedBox(height: Spacing.space12),
                      _buildBottomRow(gt, post),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Publisher avatar + name row at top.
  Widget _buildPublisherRow(GlassThemeData gt, Post post) {
    final hasAvatar = post.publisherAvatar != null && post.publisherAvatar!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: gt.colors.glassL2Bg,
            backgroundImage: hasAvatar
                ? CachedNetworkImageProvider(post.publisherAvatar!)
                : null,
            child: hasAvatar
                ? null
                : Icon(Icons.person, size: 14, color: gt.colors.textTertiary),
          ),
          const SizedBox(width: Spacing.space8),
          Expanded(
            child: Text(
              post.publisherName ?? '搭子用户',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: gt.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(GlassThemeData gt, Post post) {
    final url = post.images.isNotEmpty ? post.images.first : null;
    if (url == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gt.cardGlowColors,
          ),
        ),
        child: Center(
          child: Icon(Icons.image_outlined,
              color: Colors.white.withValues(alpha: 0.6), size: 36),
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.zero),
      child: CachedNetworkImage(
        imageUrl: url,
        height: 120,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 120,
          color: gt.colors.glassL1Bg,
        ),
        errorWidget: (_, __, ___) => Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gt.cardGlowColors,
            ),
          ),
          child: Center(
            child: Icon(Icons.broken_image_outlined,
                color: Colors.white.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(GlassThemeData gt, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: gt.colors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: gt.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Bottom row: AvatarStack (participants) + slots count.
  Widget _buildBottomRow(GlassThemeData gt, Post post) {
    return Row(
      children: [
        const AvatarStack(avatarUrls: [], size: 20),
        const Spacer(),
        _SlotsBar(post: post, gt: gt),
      ],
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '时间待定';
    return DateFormat('M月d日 HH:mm').format(time);
  }
}

class PostCardSkeleton extends StatefulWidget {
  const PostCardSkeleton({super.key});

  @override
  State<PostCardSkeleton> createState() => _PostCardSkeletonState();
}

class _PostCardSkeletonState extends State<PostCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return ExcludeSemantics(
      child: GlassCard(
        level: 1,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = 0.35 + 0.35 * _c.value;
            final base = gt.colors.glassL1Bg.withValues(alpha: t);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 120, color: base),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _bar(width: 48, height: 14, color: base, radius: 999),
                      const SizedBox(height: Spacing.space8),
                      _bar(
                          width: double.infinity, height: 12, color: base),
                      const SizedBox(height: 6),
                      _bar(width: 120, height: 12, color: base),
                      const SizedBox(height: 10),
                      _bar(width: 100, height: 10, color: base),
                      const SizedBox(height: Spacing.space4),
                      _bar(width: 80, height: 10, color: base),
                      const SizedBox(height: 10),
                      _bar(
                          width: double.infinity,
                          height: 8,
                          color: base,
                          radius: 4),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bar({
    required double width,
    required double height,
    required Color color,
    double radius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// 人数进度条，同时显示男女配额（如果设置了）。
class _SlotsBar extends StatelessWidget {
  const _SlotsBar({required this.post, required this.gt});

  final Post post;
  final GlassThemeData gt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 8, color: gt.colors.glassL2Bg),
                FractionallySizedBox(
                  widthFactor: post.slotProgress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [gt.colors.primary, gt.colors.accent],
                      ),
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: gt.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
