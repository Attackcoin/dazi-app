import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/glass_card.dart';

class StepGender extends StatelessWidget {
  const StepGender({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final options = [
      ('male', l10n.onboarding_gender_male, Icons.male, 'male'),
      ('female', l10n.onboarding_gender_female, Icons.female, 'female'),
      ('other', l10n.onboarding_gender_other, Icons.person, 'tertiary'),
    ];
    return Padding(
      padding: const EdgeInsets.all(Spacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.onboarding_gender_title, style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: Spacing.space8),
          Text(
            l10n.onboarding_gender_subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: gt.colors.textSecondary),
          ),
          const SizedBox(height: 40),
          ...options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: Spacing.space12),
                child: _GenderCard(
                  value: o.$1,
                  label: o.$2,
                  icon: o.$3,
                  colorKey: o.$4,
                  selected: value == o.$1,
                  onTap: () => onChanged(o.$1),
                ),
              )),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.colorKey,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final String colorKey;
  final bool selected;
  final VoidCallback onTap;

  Color _resolveColor(GlassThemeData gt) {
    switch (colorKey) {
      case 'male':
        return gt.colors.male;
      case 'female':
        return gt.colors.female;
      default:
        return gt.colors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final color = _resolveColor(gt);

    return GlassCard(
      level: 1,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(Spacing.space20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: Spacing.space16),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: gt.colors.textPrimary,
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check_circle, color: color, size: 24)
          else
            const SizedBox(width: 24),
        ],
      ),
    );
  }
}
