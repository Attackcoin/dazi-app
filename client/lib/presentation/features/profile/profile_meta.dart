part of 'profile_screen.dart';

// ============================================================
// 性别 / 年龄 / 城市 / bio / 标签 / 统计
// ============================================================

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 性别 / 年龄 / 城市 chip 行
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: _genderIcon(user.gender),
                label: _genderLabel(user.gender),
                color: _genderColor(gt, user.gender),
              ),
              if (user.age != null)
                _InfoChip(
                  icon: Icons.cake_outlined,
                  label: '${user.age} 岁',
                  color: gt.colors.textSecondary,
                ),
              if (user.city.isNotEmpty)
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  label: user.city,
                  color: gt.colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // bio
          if (user.bio.trim().isEmpty)
            Text(
              '这位搭子还没有写简介',
              style: TextStyle(color: gt.colors.textTertiary, fontSize: 13),
            )
          else
            Semantics(
              label: '个人简介',
              child: Text(
                user.bio,
                style: TextStyle(
                  color: gt.colors.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          const SizedBox(height: 20),
          _StatsRow(user: user),
          const SizedBox(height: 20),
          _SectionTitle('兴趣标签'),
          const SizedBox(height: 10),
          if (user.tags.isEmpty)
            Text('还没有设置兴趣标签',
                style: TextStyle(color: gt.colors.textTertiary, fontSize: 13))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: gt.colors.glassL1Bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: gt.colors.glassL1Border),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                color: gt.colors.textPrimary)),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static IconData _genderIcon(String g) => switch (g) {
        'male' => Icons.male,
        'female' => Icons.female,
        _ => Icons.transgender,
      };
  static String _genderLabel(String g) => switch (g) {
        'male' => '男',
        'female' => '女',
        _ => '其他',
      };
  static Color _genderColor(GlassThemeData gt, String g) => switch (g) {
        'male' => gt.colors.male,
        'female' => gt.colors.female,
        _ => gt.colors.textSecondary,
      };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: gt.colors.glassL1Bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gt.colors.glassL1Border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: gt.colors.glassL1Bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gt.colors.glassL1Border),
      ),
      child: Row(
        children: [
          _item(gt, '${user.totalMeetups}', '已完成'),
          _divider(gt),
          _item(gt, '${user.ghostCount}', '爽约'),
          _divider(gt),
          _item(gt, '${user.badges.length}', '勋章'),
        ],
      ),
    );
  }

  Widget _item(GlassThemeData gt, String value, String label) => Expanded(
        child: Semantics(
          label: '$label $value',
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: gt.colors.textPrimary)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: gt.colors.textSecondary)),
            ],
          ),
        ),
      );

  Widget _divider(GlassThemeData gt) => Container(
        width: 1,
        height: 28,
        color: gt.colors.glassL1Border,
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: gt.colors.textPrimary,
      ),
    );
  }
}
