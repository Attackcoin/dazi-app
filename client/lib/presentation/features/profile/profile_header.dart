part of 'profile_screen.dart';

// ============================================================
// 头部渐变 + 头像 + 昵称 + 评分 + 信用徽章
// ============================================================

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A65), Color(0xFFFF6B9D), Color(0xFFA855F7)],
      )),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'avatar-${user.id}',
                child: _Avatar(url: user.avatar, size: 80),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '昵称 ${user.name}',
                header: true,
                child: Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star, color: gt.colors.starColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    user.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '· ',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${user.reviewCount} 条评价',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  if (user.sesameAuthorized) const _SesameBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SesameBadge extends StatelessWidget {
  const _SesameBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '信用徽章：芝麻信用已授权',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white54),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, color: Colors.white, size: 13),
            SizedBox(width: 3),
            Text('信用',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '用户头像',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: Colors.white24,
        ),
        child: ClipOval(
          child: url.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 40)
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.white24,
                  ),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.person, color: Colors.white, size: 40),
                ),
        ),
      ),
    );
  }
}
