// ignore_for_file: invalid_use_of_protected_member
// 说明：扩展方法调用 State.setState 会触发 invalid_use_of_protected_member，
// 但本文件作为 part of 与主 State 类处于同一 library，语义上等同于类内调用。
part of 'create_post_screen.dart';

/// 性别配额分区 —— 从 create_post_screen.dart 拆出降低文件体积。
extension _GenderQuotaSection on _CreatePostScreenState {
  Widget _buildGenderQuotaSection() {
    final male = _draft.maleQuota ?? 0;
    final female = _draft.femaleQuota ?? 0;
    final total = _draft.totalSlots;
    final colors = GlassTheme.of(context).colors;

    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.createPost_genderQuota,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.createPost_genderQuotaOptional,
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
              const Spacer(),
              Switch(
                value: _genderQuotaEnabled,
                activeColor: colors.primary,
                onChanged: (v) => setState(() {
                  _genderQuotaEnabled = v;
                  if (v) {
                    _draft.maleQuota = (total / 2).floor();
                    _draft.femaleQuota = total - _draft.maleQuota!;
                  } else {
                    _draft.maleQuota = null;
                    _draft.femaleQuota = null;
                  }
                }),
              ),
            ],
          ),
          if (_genderQuotaEnabled) ...[
            _quotaSlider(
              label: l10n.createPost_genderQuotaMale,
              icon: Icons.male,
              value: male,
              total: total,
              colors: colors,
              onChanged: (v) => setState(() {
                _draft.maleQuota = v;
                if (v + (_draft.femaleQuota ?? 0) > total) {
                  _draft.femaleQuota = total - v;
                }
              }),
            ),
            _quotaSlider(
              label: l10n.createPost_genderQuotaFemale,
              icon: Icons.female,
              value: female,
              total: total,
              colors: colors,
              onChanged: (v) => setState(() {
                _draft.femaleQuota = v;
                if (v + (_draft.maleQuota ?? 0) > total) {
                  _draft.maleQuota = total - v;
                }
              }),
            ),
            Text(
              l10n.createPost_genderQuotaTotal(male + female, total),
              style: TextStyle(
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quotaSlider({
    required String label,
    required IconData icon,
    required int value,
    required int total,
    required DaziColorScheme colors,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.textSecondary),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textPrimary),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: total.toDouble(),
            divisions: total,
            label: '$value',
            activeColor: colors.primary,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
