import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/pill_tag.dart';
import '../../../../data/services/location_service.dart';

class StepCity extends ConsumerStatefulWidget {
  const StepCity({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<StepCity> createState() => _StepCityState();
}

class _StepCityState extends ConsumerState<StepCity> {
  bool _locating = true; // 一进来就开始定位

  // 中国热门
  static const _cnCities = [
    '北京', '上海', '广州', '深圳',
    '杭州', '成都', '南京', '武汉',
  ];

  // 全球热门
  static const _globalCities = [
    'Tokyo', 'Seoul', 'Singapore', 'Bangkok',
    'New York', 'London', 'Paris', 'Sydney',
    'Los Angeles', 'Toronto', 'Dubai', 'Berlin',
  ];

  @override
  void initState() {
    super.initState();
    // 页面加载后自动定位
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLocate());
  }

  Future<void> _autoLocate() async {
    try {
      final result =
          await ref.read(locationServiceProvider).getCurrentCity();
      if (!mounted) return;
      if (result != null && widget.value.isEmpty) {
        widget.onChanged(result.city);
      }
    } catch (_) {
      // 定位失败静默处理，用户可以手动选
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(Spacing.space24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.onboarding_city_title,
                style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: Spacing.space8),
            Text(
              l10n.onboarding_city_subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: gt.colors.textSecondary),
            ),
            const SizedBox(height: Spacing.space24),

            // 定位状态 / 定位结果
            if (_locating)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space16, vertical: Spacing.space12),
                decoration: BoxDecoration(
                  color: gt.colors.glassL1Bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gt.colors.glassL1Border),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: gt.colors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.onboarding_city_locating,
                        style: TextStyle(
                            fontSize: 14, color: gt.colors.textSecondary)),
                  ],
                ),
              )
            else if (widget.value.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space16, vertical: 10),
                decoration: BoxDecoration(
                  color: gt.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: gt.colors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: gt.colors.primary, size: 18),
                    const SizedBox(width: Spacing.space8),
                    Expanded(
                      child: Text(
                        widget.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: gt.colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 28),
            Text(
              l10n.onboarding_city_cnHot,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gt.colors.textPrimary),
            ),
            const SizedBox(height: Spacing.space12),
            _buildCityChips(_cnCities),

            const SizedBox(height: Spacing.space24),
            Text(
              l10n.onboarding_city_global,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gt.colors.textPrimary),
            ),
            const SizedBox(height: Spacing.space12),
            _buildCityChips(_globalCities),

            const SizedBox(height: 28),
            Text(
              l10n.onboarding_city_manualInput,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gt.colors.textPrimary),
            ),
            const SizedBox(height: Spacing.space12),
            TextField(
              decoration: InputDecoration(
                hintText: l10n.onboarding_city_searchHint,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: widget.onChanged,
              controller: TextEditingController(text: widget.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityChips(List<String> cities) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: cities.map((c) {
        final isSelected = widget.value == c;
        return PillTag(
          label: c,
          selected: isSelected,
          onTap: () => widget.onChanged(c),
        );
      }).toList(),
    );
  }
}
