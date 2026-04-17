import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/repositories/venue_repository.dart';

/// 场地详情页。
class VenueDetailScreen extends ConsumerStatefulWidget {
  const VenueDetailScreen({super.key, required this.venueId});
  final String venueId;

  @override
  ConsumerState<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends ConsumerState<VenueDetailScreen> {
  bool _checkingIn = false;

  Future<void> _checkin() async {
    setState(() => _checkingIn = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final perks = await ref
          .read(venueRepositoryProvider)
          .venueCheckin(venueId: widget.venueId);
      if (!mounted) return;
      final msg = perks.isNotEmpty
          ? '${l10n.venue_checkinSuccess} ${l10n.venue_perks}: ${perks.join(', ')}'
          : l10n.venue_checkinSuccess;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString();
      final msg = errStr.contains('already')
          ? l10n.venue_alreadyCheckedIn
          : l10n.venue_checkinFailed(errStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final venueAsync = ref.watch(venueProvider(widget.venueId));

    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: venueAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(l10n.common_loadFailed,
                style: TextStyle(color: gt.colors.textSecondary)),
          ),
          data: (venue) {
            if (venue == null) {
              return Center(
                child: Text(l10n.common_loadFailed,
                    style: TextStyle(color: gt.colors.textSecondary)),
              );
            }
            return CustomScrollView(
              slivers: [
                // 封面图 + AppBar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  expandedHeight: venue.coverImage.isNotEmpty ? 220 : 0,
                  pinned: true,
                  title: Text(venue.name),
                  flexibleSpace: venue.coverImage.isNotEmpty
                      ? FlexibleSpaceBar(
                          background: CachedNetworkImage(
                            imageUrl: venue.coverImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: gt.colors.glassL2Bg),
                            errorWidget: (_, __, ___) =>
                                Container(color: gt.colors.glassL2Bg),
                          ),
                        )
                      : null,
                ),
                // 场地信息卡
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.space16,
                      vertical: Spacing.space8,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(Spacing.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 名称 + 分类
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  venue.name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: gt.colors.textPrimary,
                                  ),
                                ),
                              ),
                              PillTag(label: venue.category),
                            ],
                          ),
                          const SizedBox(height: Spacing.space8),
                          // 地址
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 16, color: gt.colors.textTertiary),
                              const SizedBox(width: Spacing.space4),
                              Expanded(
                                child: Text(
                                  venue.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: gt.colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.space8),
                          // 签到数
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16, color: gt.colors.primary),
                              const SizedBox(width: Spacing.space4),
                              Text(
                                l10n.venue_totalCheckins(venue.totalCheckins),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: gt.colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          // 描述
                          if (venue.description.isNotEmpty) ...[
                            const SizedBox(height: Spacing.space12),
                            Text(
                              venue.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: gt.colors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // 福利卡片
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.space16,
                      vertical: Spacing.space4,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(Spacing.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.card_giftcard,
                                  size: 18, color: gt.colors.info),
                              const SizedBox(width: Spacing.space8),
                              Text(
                                l10n.venue_perks,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: gt.colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.space12),
                          if (venue.perks.isEmpty)
                            Text(
                              l10n.venue_noPerks,
                              style: TextStyle(
                                fontSize: 14,
                                color: gt.colors.textTertiary,
                              ),
                            )
                          else
                            Wrap(
                              spacing: Spacing.space8,
                              runSpacing: Spacing.space8,
                              children: venue.perks.map((p) {
                                return PillTag(
                                  label: p,
                                  color: gt.colors.info,
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 图片画廊
                if (venue.images.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.space16,
                        vertical: Spacing.space4,
                      ),
                      child: SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: venue.images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: Spacing.space8),
                          itemBuilder: (_, index) {
                            return ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(Radii.pill),
                              child: CachedNetworkImage(
                                imageUrl: venue.images[index],
                                width: 160,
                                height: 120,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 160,
                                  color: gt.colors.glassL2Bg,
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 160,
                                  color: gt.colors.glassL2Bg,
                                  child: Icon(Icons.image,
                                      color: gt.colors.textTertiary),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                // 签到按钮
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.space16),
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _checkingIn ? null : _checkin,
                        icon: _checkingIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          l10n.venue_checkinButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gt.colors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Radii.button),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 底部留白
                const SliverToBoxAdapter(
                  child: SizedBox(height: Spacing.space32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
