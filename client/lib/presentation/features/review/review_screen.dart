import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../data/repositories/review_repository.dart';

/// 评价页 —— 星级 + 标签 + 文字。提交后跳到回忆卡页。
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  int _rating = 5;
  final Set<String> _selectedTags = {};
  final _commentController = TextEditingController();
  bool _submitting = false;

  static const _positiveTags = [
    '好相处', '守时', '靠谱', '聊得来', '有礼貌',
    '热情', '氛围感', '会照顾人',
  ];

  static const _negativeTags = [
    '放鸽子', '迟到', '态度差', '不合群',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppMatch match, String myUid) async {
    final other = match.otherOf(myUid);
    if (other == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(reviewRepositoryProvider).submit(
            matchId: match.id,
            toUserId: other.uid,
            rating: _rating,
            comment: _commentController.text.trim(),
            tags: _selectedTags.toList(),
          );
      if (!mounted) return;
      // 评价完跳到回忆卡页
      context.pushReplacement('/recap/${match.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = RegExp(r'message: ([^,)]+)').firstMatch(e.toString())?.group(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败：${msg ?? e}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('写评价', style: TextStyle(color: gt.colors.textPrimary)),
          iconTheme: IconThemeData(color: gt.colors.textPrimary),
        ),
        body: matchAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: gt.colors.textTertiary),
                  const SizedBox(height: 12),
                  Text('加载失败：$e', textAlign: TextAlign.center,
                      style: TextStyle(color: gt.colors.textPrimary)),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(matchByIdProvider(widget.matchId)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          data: (match) {
            if (match == null) return Center(child: Text('搭子不存在', style: TextStyle(color: gt.colors.textPrimary)));
            final other = match.otherOf(myUid);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              children: [
                GlassCard(
                  level: 1,
                  padding: const EdgeInsets.all(20),
                  child: _buildTarget(gt, other),
                ),
                const SizedBox(height: 32),
                _buildStars(gt),
                const SizedBox(height: 28),
                _sectionLabel(gt, '好的印象'),
                const SizedBox(height: 10),
                _buildTagWrap(gt, _positiveTags, false),
                const SizedBox(height: 20),
                _sectionLabel(gt, '需要改进'),
                const SizedBox(height: 10),
                _buildTagWrap(gt, _negativeTags, true),
                const SizedBox(height: 28),
                _sectionLabel(gt, '留言'),
                const SizedBox(height: 10),
                GlassInput(
                  controller: _commentController,
                  hint: '对这次搭子的感受、想说的话...',
                  maxLines: 4,
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: gt.colors.surface,
            border: Border(top: BorderSide(color: gt.colors.glassL1Border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: GlassButton(
              label: '提交评价',
              variant: GlassButtonVariant.primary,
              expand: true,
              isLoading: _submitting,
              onPressed: _submitting
                  ? null
                  : () {
                      final match = matchAsync.valueOrNull;
                      if (match != null) _submit(match, myUid);
                    },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTarget(GlassThemeData gt, MatchParticipant? other) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: gt.colors.glassL1Bg,
          backgroundImage: (other?.avatar.isNotEmpty ?? false)
              ? CachedNetworkImageProvider(other!.avatar)
              : null,
          child: (other?.avatar.isEmpty ?? true)
              ? Icon(Icons.person, size: 40, color: gt.colors.textSecondary)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          other?.name ?? '搭子',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: gt.colors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '这次搭子体验如何？',
          style: TextStyle(fontSize: 13, color: gt.colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStars(GlassThemeData gt) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = i < _rating;
        return GestureDetector(
          onTap: () => setState(() => _rating = i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 44,
              color: filled ? gt.colors.starColor : gt.colors.textTertiary,
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(GlassThemeData gt, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: gt.colors.textPrimary,
        ),
      );

  Widget _buildTagWrap(GlassThemeData gt, List<String> tags, bool isNegative) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((t) {
        final selected = _selectedTags.contains(t);
        final activeColor = isNegative ? gt.colors.error : gt.colors.primary;
        return GestureDetector(
          onTap: () => setState(() {
            if (selected) {
              _selectedTags.remove(t);
            } else {
              _selectedTags.add(t);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? activeColor : gt.colors.glassL1Bg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? activeColor : gt.colors.glassL1Border,
              ),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: selected ? Colors.white : gt.colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
