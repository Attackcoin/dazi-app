import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/match_repository.dart';
import '../../../data/repositories/review_repository.dart';

/// 回忆卡页 —— 显示 AI 生成的活动总结，可分享。
class RecapCardScreen extends ConsumerStatefulWidget {
  const RecapCardScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<RecapCardScreen> createState() => _RecapCardScreenState();
}

class _RecapCardScreenState extends ConsumerState<RecapCardScreen> {
  bool _regenerating = false;

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      await ref.read(reviewRepositoryProvider).generateRecap(widget.matchId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享功能待接入')),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: matchAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (e, _) => Center(
              child: Text('加载失败：$e',
                  style: const TextStyle(color: Colors.white)),
            ),
            data: (match) {
              if (match == null) {
                return const Center(
                  child: Text('搭子不存在',
                      style: TextStyle(color: Colors.white)),
                );
              }
              final recap = match.recapCard;
              if (recap == null) {
                return _PendingRecap(
                  regenerating: _regenerating,
                  onRegenerate: _regenerate,
                );
              }
              return _RecapContent(recap: recap, match: match);
            },
          ),
        ),
      ),
    );
  }
}

class _RecapContent extends StatelessWidget {
  const _RecapContent({required this.recap, required this.match});

  final RecapCard recap;
  final AppMatch match;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
      child: Column(
        children: [
          const Text(
            '✨ 搭子回忆卡',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  '"${recap.summary}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 20),
                _recapRow(Icons.local_activity_outlined, '活动', recap.activity),
                const SizedBox(height: 12),
                _recapRow(Icons.location_on_outlined, '地点', recap.location),
                const SizedBox(height: 12),
                _recapRow(
                  Icons.group_outlined,
                  '人数',
                  '${recap.participants} 人',
                ),
                if (recap.duration != null) ...[
                  const SizedBox(height: 12),
                  _recapRow(
                    Icons.schedule,
                    '时长',
                    '${recap.duration} 分钟',
                  ),
                ],
                if (recap.generatedAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    DateFormat('yyyy.MM.dd').format(recap.generatedAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
            ),
            icon: const Icon(Icons.home),
            label: const Text('回到广场'),
          ),
        ],
      ),
    );
  }

  Widget _recapRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingRecap extends StatelessWidget {
  const _PendingRecap({required this.regenerating, required this.onRegenerate});

  final bool regenerating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'AI 正在为你生成回忆卡',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '稍等片刻或手动触发',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: regenerating ? null : onRegenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              icon: regenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('生成回忆卡'),
            ),
          ],
        ),
      ),
    );
  }
}
