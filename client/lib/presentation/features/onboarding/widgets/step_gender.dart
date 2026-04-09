import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StepGender extends StatelessWidget {
  const StepGender({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('male', '男生', Icons.male, AppColors.male),
    ('female', '女生', Icons.female, AppColors.female),
    ('other', '不透露', Icons.person, AppColors.textTertiary),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你的性别', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            '这会影响搭子的男女配额匹配',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          ..._options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GenderCard(
                  value: o.$1,
                  label: o.$2,
                  icon: o.$3,
                  color: o.$4,
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
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 24)
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}
