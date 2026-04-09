import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
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
    '靠谱守时', '聊得来', '有礼貌', '热情', '懂生活',
    '颜值担当', '氛围感', '干净整洁', '会照顾人',
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
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('写评价')),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (match) {
          if (match == null) return const Center(child: Text('搭子不存在'));
          final other = match.otherOf(myUid);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              _buildTarget(other),
              const SizedBox(height: 32),
              _buildStars(),
              const SizedBox(height: 28),
              _sectionLabel('印象标签（可多选）'),
              const SizedBox(height: 10),
              _buildTagWrap(),
              const SizedBox(height: 28),
              _sectionLabel('留言'),
              const SizedBox(height: 10),
              TextField(
                controller: _commentController,
                maxLines: 4,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: '对这次搭子的感受、想说的话...',
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: _submitting
                ? null
                : () {
                    final match = matchAsync.valueOrNull;
                    if (match != null) _submit(match, myUid);
                  },
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('提交评价'),
          ),
        ),
      ),
    );
  }

  Widget _buildTarget(MatchParticipant? other) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.surfaceAlt,
          backgroundImage: (other?.avatar.isNotEmpty ?? false)
              ? CachedNetworkImageProvider(other!.avatar)
              : null,
          child: (other?.avatar.isEmpty ?? true)
              ? const Icon(Icons.person, size: 40)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          other?.name ?? '搭子',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '这次搭子体验如何？',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStars() {
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
              color: filled ? Colors.amber : AppColors.textTertiary,
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _buildTagWrap() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _positiveTags.map((t) {
        final selected = _selectedTags.contains(t);
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
              color: selected ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
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
