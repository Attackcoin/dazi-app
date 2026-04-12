import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/pill_tag.dart';
import '../../../../data/repositories/category_repository.dart';

class StepTags extends ConsumerWidget {
  const StepTags({
    super.key,
    required this.selected,
    required this.socialAnxietyMode,
    required this.onTagsChanged,
    required this.onSocialAnxietyChanged,
  });

  final List<String> selected;
  final bool socialAnxietyMode;
  final ValueChanged<List<String>> onTagsChanged;
  final ValueChanged<bool> onSocialAnxietyChanged;

  void _toggle(String tag) {
    final next = List<String>.from(selected);
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    onTagsChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          Spacing.space24, Spacing.space24, Spacing.space24, Spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选几个感兴趣的', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: Spacing.space8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '至少选 1 个，AI 会帮你匹配同好',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: gt.colors.textSecondary),
                ),
              ),
              if (selected.isNotEmpty)
                Text(
                  '已选 ${selected.length}',
                  style: TextStyle(
                    color: gt.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.space24),
          ...categories.map((c) =>
              _buildGroup(context, gt, '${c.emoji} ${c.label}', c.tags)),
          const SizedBox(height: Spacing.space12),
          // 胆小鬼模式 toggle — GlassCard
          GlassCard(
            level: 1,
            padding: const EdgeInsets.all(Spacing.space16),
            child: Row(
              children: [
                const Text('🫣', style: TextStyle(fontSize: 24)),
                const SizedBox(width: Spacing.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '胆小鬼模式',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: gt.colors.textPrimary,
                        ),
                      ),
                      Text(
                        '优先推荐社恐友好的活动',
                        style: TextStyle(
                          fontSize: 12,
                          color: gt.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: socialAnxietyMode,
                  onChanged: onSocialAnxietyChanged,
                  activeColor: gt.colors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, GlassThemeData gt, String title,
      List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: gt.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: Spacing.space8,
          runSpacing: Spacing.space8,
          children: tags.map((tag) {
            final isSelected = selected.contains(tag);
            return PillTag(
              label: tag,
              selected: isSelected,
              onTap: () => _toggle(tag),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
