import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/models/venue.dart';
import '../../../data/repositories/venue_repository.dart';

/// 合作场地列表页。
class VenuesScreen extends ConsumerWidget {
  const VenuesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final venuesAsync = ref.watch(venuesProvider);

    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              title: Text(l10n.venue_title),
              centerTitle: false,
              floating: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_business_outlined),
                  tooltip: l10n.venue_registerTitle,
                  onPressed: () => _showRegisterSheet(context, ref),
                ),
              ],
            ),
            venuesAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    l10n.common_loadFailed,
                    style: TextStyle(color: gt.colors.textSecondary),
                  ),
                ),
              ),
              data: (venues) {
                if (venues.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_outlined,
                              size: 64, color: gt.colors.textTertiary),
                          const SizedBox(height: Spacing.space12),
                          Text(
                            l10n.venue_emptyList,
                            style: TextStyle(color: gt.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space16,
                    vertical: Spacing.space8,
                  ),
                  sliver: SliverList.separated(
                    itemCount: venues.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Spacing.space12),
                    itemBuilder: (context, index) =>
                        _VenueCard(venue: venues[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRegisterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RegisterVenueSheet(),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GlassCard(
      onTap: () => context.push('/venue/${venue.id}'),
      padding: const EdgeInsets.all(Spacing.space16),
      child: Row(
        children: [
          // 场地图标/封面
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: venue.coverImage.isNotEmpty
                ? Image.network(
                    venue.coverImage,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultIcon(gt),
                  )
                : _defaultIcon(gt),
          ),
          const SizedBox(width: Spacing.space12),
          // 场地信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.space4),
                Row(
                  children: [
                    PillTag(label: venue.category),
                    const SizedBox(width: Spacing.space8),
                    Expanded(
                      child: Text(
                        venue.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: gt.colors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.space8),
          // 签到数
          Column(
            children: [
              Text(
                '${venue.totalCheckins}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: gt.colors.primary,
                ),
              ),
              Text(
                l10n.venue_checkins,
                style: TextStyle(
                  fontSize: 11,
                  color: gt.colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _defaultIcon(GlassThemeData gt) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: gt.colors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.storefront, size: 28, color: gt.colors.primary),
    );
  }
}

/// 入驻申请底部弹窗。
class _RegisterVenueSheet extends ConsumerStatefulWidget {
  const _RegisterVenueSheet();

  @override
  ConsumerState<_RegisterVenueSheet> createState() =>
      _RegisterVenueSheetState();
}

class _RegisterVenueSheetState extends ConsumerState<_RegisterVenueSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _perkCtrl = TextEditingController();
  String _category = '咖啡厅';
  final List<String> _perks = [];
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _perkCtrl.dispose();
    super.dispose();
  }

  void _addPerk() {
    final perk = _perkCtrl.text.trim();
    if (perk.isEmpty || _perks.length >= 5) return;
    setState(() {
      _perks.add(perk);
      _perkCtrl.clear();
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    if (name.isEmpty || address.isEmpty) return;

    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      await ref.read(venueRepositoryProvider).registerVenue(
            name: name,
            description: _descCtrl.text.trim(),
            category: _category,
            address: address,
            contactName: _contactCtrl.text.trim(),
            contactPhone: _phoneCtrl.text.trim(),
            perks: _perks,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.venue_registerSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.venue_registerFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final categories = [
      l10n.venue_categoryCafe,
      l10n.venue_categoryGym,
      l10n.venue_categoryBar,
      l10n.venue_categoryRestaurant,
      l10n.venue_categoryOther,
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassCard(
        level: 2,
        useBlur: true,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
        padding: const EdgeInsets.all(Spacing.space24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 拖拽手柄
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: gt.colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: Spacing.space16),
              Text(
                l10n.venue_registerTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: gt.colors.textPrimary,
                ),
              ),
              const SizedBox(height: Spacing.space16),
              // 场地名称
              _buildField(
                gt,
                controller: _nameCtrl,
                label: l10n.venue_registerName,
                hint: l10n.venue_registerNameHint,
                maxLength: 50,
              ),
              const SizedBox(height: Spacing.space12),
              // 地址
              _buildField(
                gt,
                controller: _addressCtrl,
                label: l10n.venue_registerAddress,
                hint: l10n.venue_registerAddressHint,
              ),
              const SizedBox(height: Spacing.space12),
              // 分类
              Text(
                l10n.venue_registerCategory,
                style: TextStyle(
                  fontSize: 13,
                  color: gt.colors.textSecondary,
                ),
              ),
              const SizedBox(height: Spacing.space4),
              Wrap(
                spacing: Spacing.space8,
                children: categories.map((c) {
                  final selected = c == _category;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    selectedColor: gt.colors.primary.withValues(alpha: 0.2),
                    backgroundColor: gt.colors.glassL2Bg,
                    labelStyle: TextStyle(
                      color: selected
                          ? gt.colors.primary
                          : gt.colors.textSecondary,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: selected
                          ? gt.colors.primary
                          : gt.colors.glassL2Border,
                    ),
                    onSelected: (_) => setState(() => _category = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: Spacing.space12),
              // 描述
              _buildField(
                gt,
                controller: _descCtrl,
                label: l10n.venue_registerDesc,
                hint: l10n.venue_registerDescHint,
                maxLines: 2,
              ),
              const SizedBox(height: Spacing.space12),
              // 联系人 + 电话
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      gt,
                      controller: _contactCtrl,
                      label: l10n.venue_registerContact,
                    ),
                  ),
                  const SizedBox(width: Spacing.space12),
                  Expanded(
                    child: _buildField(
                      gt,
                      controller: _phoneCtrl,
                      label: l10n.venue_registerPhone,
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.space12),
              // 福利
              Text(
                l10n.venue_registerPerks,
                style: TextStyle(
                  fontSize: 13,
                  color: gt.colors.textSecondary,
                ),
              ),
              const SizedBox(height: Spacing.space4),
              if (_perks.isNotEmpty)
                Wrap(
                  spacing: Spacing.space8,
                  runSpacing: Spacing.space4,
                  children: _perks.map((p) {
                    return PillTag(
                      label: p,
                      color: gt.colors.info,
                      onTap: () => setState(() => _perks.remove(p)),
                    );
                  }).toList(),
                ),
              if (_perks.length < 5) ...[
                const SizedBox(height: Spacing.space4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _perkCtrl,
                        style: TextStyle(
                          color: gt.colors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.venue_registerPerksHint,
                          hintStyle: TextStyle(
                            color: gt.colors.textTertiary,
                            fontSize: 13,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: Spacing.space12,
                            vertical: Spacing.space8,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.input),
                            borderSide:
                                BorderSide(color: gt.colors.glassL2Border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.input),
                            borderSide: BorderSide(color: gt.colors.primary),
                          ),
                        ),
                        onSubmitted: (_) => _addPerk(),
                      ),
                    ),
                    const SizedBox(width: Spacing.space8),
                    IconButton(
                      onPressed: _addPerk,
                      icon: Icon(Icons.add_circle_outline,
                          color: gt.colors.primary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Spacing.space16),
              // 提交按钮
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gt.colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Radii.button),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.venue_registerButton),
                ),
              ),
              const SizedBox(height: Spacing.space8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    GlassThemeData gt, {
    required TextEditingController controller,
    required String label,
    String? hint,
    int? maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: gt.colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: gt.colors.textSecondary),
        hintStyle: TextStyle(color: gt.colors.textTertiary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.input),
          borderSide: BorderSide(color: gt.colors.glassL2Border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.input),
          borderSide: BorderSide(color: gt.colors.primary),
        ),
      ),
    );
  }
}
