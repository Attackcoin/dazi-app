import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/circle.dart';
import '../../../data/repositories/circle_repository.dart';

/// 圈子列表页 —— 展示所有圈子，可创建新圈��。
class CirclesScreen extends ConsumerWidget {
  const CirclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final circlesAsync = ref.watch(circlesProvider);

    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              title: Text(l10n.circle_title),
              centerTitle: false,
              floating: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _showCreateDialog(context, ref),
                ),
              ],
            ),
            circlesAsync.when(
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
              data: (circles) {
                if (circles.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined,
                              size: 64, color: gt.colors.textTertiary),
                          const SizedBox(height: Spacing.space12),
                          Text(
                            l10n.circle_emptyList,
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
                    itemCount: circles.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Spacing.space12),
                    itemBuilder: (context, index) =>
                        _CircleCard(circle: circles[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateCircleSheet(),
    );
  }
}

class _CircleCard extends ConsumerWidget {
  const _CircleCard({required this.circle});
  final Circle circle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GlassCard(
      onTap: () => context.push('/circle/${circle.id}'),
      padding: const EdgeInsets.all(Spacing.space16),
      child: Row(
        children: [
          // 圈子图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: gt.colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            alignment: Alignment.center,
            child: Text(
              circle.icon.isNotEmpty ? circle.icon : circle.name.characters.first,
              style: TextStyle(
                fontSize: circle.icon.isNotEmpty ? 24 : 20,
                fontWeight: FontWeight.w600,
                color: gt.colors.primary,
              ),
            ),
          ),
          const SizedBox(width: Spacing.space12),
          // 圈子信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  circle.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Spacing.space4),
                Text(
                  circle.description.isNotEmpty
                      ? circle.description
                      : circle.creatorName,
                  style: TextStyle(
                    fontSize: 13,
                    color: gt.colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.space8),
          // 成员数
          Column(
            children: [
              Text(
                '${circle.memberCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: gt.colors.primary,
                ),
              ),
              Text(
                l10n.circle_members,
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
}

/// 创建圈子的底部弹窗。
class _CreateCircleSheet extends ConsumerStatefulWidget {
  const _CreateCircleSheet();

  @override
  ConsumerState<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends ConsumerState<_CreateCircleSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final circleId = await ref.read(circleRepositoryProvider).createCircle(
            name: name,
            description: _descCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.circle_createSuccess)),
      );
      context.push('/circle/$circleId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.circle_createFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
              l10n.circle_create,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: gt.colors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.space16),
            TextField(
              controller: _nameCtrl,
              maxLength: 30,
              style: TextStyle(color: gt.colors.textPrimary),
              decoration: InputDecoration(
                labelText: l10n.circle_createName,
                hintText: l10n.circle_createNameHint,
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
            ),
            const SizedBox(height: Spacing.space12),
            TextField(
              controller: _descCtrl,
              maxLength: 500,
              maxLines: 3,
              style: TextStyle(color: gt.colors.textPrimary),
              decoration: InputDecoration(
                labelText: l10n.circle_createDesc,
                hintText: l10n.circle_createDescHint,
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
            ),
            const SizedBox(height: Spacing.space16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _create,
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
                    : Text(l10n.circle_createButton),
              ),
            ),
            const SizedBox(height: Spacing.space8),
          ],
        ),
      ),
    );
  }
}
