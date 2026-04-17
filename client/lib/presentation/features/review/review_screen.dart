import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/error_retry_view.dart';
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
        SnackBar(content: Text(AppLocalizations.of(context)!.review_submitFailed('${msg ?? e}'))),
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
          title: Text(AppLocalizations.of(context)!.review_title, style: TextStyle(color: gt.colors.textPrimary)),
          iconTheme: IconThemeData(color: gt.colors.textPrimary),
        ),
        body: matchAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetryView(
            error: e,
            onRetry: () => ref.invalidate(matchByIdProvider(widget.matchId)),
          ),
          data: (match) {
            if (match == null) return Center(child: Text(AppLocalizations.of(context)!.review_matchNotExist, style: TextStyle(color: gt.colors.textPrimary)));
            final l10n = AppLocalizations.of(context)!;
            final other = match.otherOf(myUid);
            final positiveTags = [
              l10n.review_tag_nice, l10n.review_tag_punctual, l10n.review_tag_reliable,
              l10n.review_tag_chatty, l10n.review_tag_polite, l10n.review_tag_passionate,
              l10n.review_tag_vibes, l10n.review_tag_caring,
            ];
            final negativeTags = [
              l10n.review_tag_ghosted, l10n.review_tag_late,
              l10n.review_tag_attitude, l10n.review_tag_unsocial,
            ];
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
                _sectionLabel(gt, l10n.review_positiveLabel),
                const SizedBox(height: 10),
                _buildTagWrap(gt, positiveTags, false),
                const SizedBox(height: 20),
                _sectionLabel(gt, l10n.review_negativeLabel),
                const SizedBox(height: 10),
                _buildTagWrap(gt, negativeTags, true),
                const SizedBox(height: 28),
                _sectionLabel(gt, l10n.review_commentLabel),
                const SizedBox(height: 10),
                GlassInput(
                  controller: _commentController,
                  hint: l10n.review_commentHint,
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
              label: AppLocalizations.of(context)!.review_submitButton,
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
          other?.name ?? AppLocalizations.of(context)!.review_partner,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
              color: gt.colors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.review_experienceQuestion,
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
