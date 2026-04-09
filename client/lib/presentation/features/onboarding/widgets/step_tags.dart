import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StepTags extends StatelessWidget {
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

  // 热门标签分组
  static const _groups = {
    '🍜 吃喝': ['咖啡', '火锅', '日料', '烧烤', '甜品', '酒吧'],
    '🏃 运动': ['跑步', '健身', '瑜伽', '骑行', '羽毛球', '游泳', '爬山'],
    '🎨 文艺': ['看展', '音乐节', 'Livehouse', '剧本杀', '话剧', '电影'],
    '✈️ 旅行': ['city walk', '露营', '自驾', '民宿', '打卡', '短途'],
    '🎮 游戏': ['桌游', '密室', '剧本杀', '电竞', '狼人杀'],
    '📚 学习': ['自习', '英语', '读书会', '编程', '考研'],
  };

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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选几个感兴趣的', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '至少选 1 个，AI 会帮你匹配同好',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              if (selected.isNotEmpty)
                Text(
                  '已选 ${selected.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ..._groups.entries.map((e) => _buildGroup(e.key, e.value)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('🫣', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '胆小鬼模式',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '优先推荐社恐友好的活动',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: socialAnxietyMode,
                  onChanged: onSocialAnxietyChanged,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String title, List<String> tags) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = selected.contains(tag);
            return GestureDetector(
              onTap: () => _toggle(tag),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}
