import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/dazi_colors.dart';
import '../../../../core/theme/glass_theme.dart';
import '../../../../core/theme/spacing.dart';

class StepYear extends StatelessWidget {
  const StepYear({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final currentYear = DateTime.now().year;
    const minYear = 1950;
    final maxYear = currentYear - 18;
    final defaultYear = value ?? (currentYear - 25);

    return Padding(
      padding: const EdgeInsets.all(Spacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你的出生年份', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: Spacing.space8),
          Text(
            '仅用于匹配同龄人，不会公开完整生日',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: gt.colors.textSecondary),
          ),
          const SizedBox(height: 40),
          Center(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: DaziColors.heroGradientColors,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$defaultYear',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: Spacing.space8),
                  const Text(
                    '年',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.space24),
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              itemExtent: 44,
              scrollController: FixedExtentScrollController(
                initialItem: defaultYear - minYear,
              ),
              onSelectedItemChanged: (i) => onChanged(minYear + i),
              children: List.generate(
                maxYear - minYear + 1,
                (i) => Center(
                  child: Text(
                    '${minYear + i}',
                    style: TextStyle(
                      fontSize: 20,
                      color: gt.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
