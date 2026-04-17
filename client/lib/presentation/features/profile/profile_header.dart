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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: DaziColors.heroGradientColors,
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
                label: user.name,
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
                    l10n.profile_reviewCount(user.reviewCount),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  if (user.verificationLevel >= 2) const _VerifiedBadge(),
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

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.profile_verifiedA11y,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_user, color: Colors.white, size: 13),
            const SizedBox(width: 3),
            Text(l10n.profile_verified,
                style: const TextStyle(
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

class _SesameBadge extends StatelessWidget {
  const _SesameBadge();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      label: l10n.profile_sesameBadgeA11y,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white54),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 13),
            const SizedBox(width: 3),
            Text(l10n.profile_sesameBadge,
                style: const TextStyle(
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
