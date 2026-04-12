import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// 重叠头像墙，最多显示 [maxVisible] 个头像 + "+N" 溢出提示。
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.avatarUrls,
    this.size = 24,
    this.overlap = 8,
    this.maxVisible = 4,
    this.borderWidth = 2,
  });

  final List<String> avatarUrls;
  final double size;
  final double overlap;
  final int maxVisible;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final borderColor = gt.isDark ? gt.colors.glassL1Border : Colors.white;
    final visibleCount = avatarUrls.length > maxVisible ? maxVisible : avatarUrls.length;
    final overflow = avatarUrls.length - maxVisible;

    return SizedBox(
      height: size,
      width: visibleCount * (size - overlap) + overlap + (overflow > 0 ? (size - overlap) + overlap : 0),
      child: Stack(
        children: [
          for (var i = 0; i < visibleCount; i++)
            Positioned(
              left: i * (size - overlap),
              child: _Avatar(
                url: avatarUrls[i],
                size: size,
                borderWidth: borderWidth,
                borderColor: borderColor,
                index: i,
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: visibleCount * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gt.colors.glassL1Bg,
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: gt.colors.textTertiary,
                    fontSize: size * 0.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.size,
    required this.borderWidth,
    required this.borderColor,
    required this.index,
  });

  final String url;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final int index;

  static const _fallbackGradients = [
    [Color(0xFFFF6B9D), Color(0xFFFF8A65)],
    [Color(0xFFA855F7), Color(0xFF6366F1)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF34D399)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _fallbackGradients[index % _fallbackGradients.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipOval(
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
      ),
    );
  }
}
