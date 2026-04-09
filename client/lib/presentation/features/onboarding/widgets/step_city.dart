import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StepCity extends StatelessWidget {
  const StepCity({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _hotCities = [
    '北京', '上海', '广州', '深圳',
    '杭州', '成都', '南京', '武汉',
    '西安', '重庆', '苏州', '长沙',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你常住哪座城市？', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            '搭子只会推荐同城的活动',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          const Text(
            '热门城市',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _hotCities.map((c) {
              final selected = value == c;
              return GestureDetector(
                onTap: () => onChanged(c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            '或手动输入',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: '输入城市名',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            onChanged: onChanged,
            controller: TextEditingController(text: value),
          ),
        ],
      ),
    );
  }
}
