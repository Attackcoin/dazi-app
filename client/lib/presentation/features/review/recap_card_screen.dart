import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
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
    final gt = GlassTheme.of(context);

    return GlowBackground(
      globs: const [GlowGlob.topRight, GlowGlob.bottomLeft, GlowGlob.centerBlue],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: gt.colors.textPrimary,
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
        body: SafeArea(
          child: matchAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(color: gt.colors.primary),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: gt.colors.textSecondary),
                    const SizedBox(height: 12),
                    Text('加载失败：$e',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: gt.colors.textPrimary)),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(matchByIdProvider(widget.matchId)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: gt.colors.textPrimary,
                        side: BorderSide(color: gt.colors.glassL1Border),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
            data: (match) {
              if (match == null) {
                return Center(
                  child: Text('搭子不存在',
                      style: TextStyle(color: gt.colors.textPrimary)),
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

// ============================================================
// 回忆卡内容（含打字机标题效果）
// ============================================================

class _RecapContent extends StatelessWidget {
  const _RecapContent({required this.recap, required this.match});

  final RecapCard recap;
  final AppMatch match;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
      child: Column(
        children: [
          _TypewriterTitle(
            text: '✨ 搭子回忆卡',
            style: TextStyle(
              color: gt.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            level: 2,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  '"${recap.summary}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: gt.colors.glassL1Border),
                const SizedBox(height: 20),
                _recapRow(gt, Icons.local_activity_outlined, '活动', recap.activity),
                const SizedBox(height: 12),
                _recapRow(gt, Icons.location_on_outlined, '地点', recap.location),
                const SizedBox(height: 12),
                _recapRow(
                  gt,
                  Icons.group_outlined,
                  '人数',
                  '${recap.participants} 人',
                ),
                if (recap.duration != null) ...[
                  const SizedBox(height: 12),
                  _recapRow(
                    gt,
                    Icons.schedule,
                    '时长',
                    '${recap.duration} 分钟',
                  ),
                ],
                if (recap.generatedAt != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    DateFormat('yyyy.MM.dd').format(recap.generatedAt!),
                    style: TextStyle(
                      fontSize: 11,
                      color: gt.colors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          GlassButton(
            label: '回到广场',
            icon: Icons.home,
            variant: GlassButtonVariant.primary,
            expand: true,
            onPressed: () => context.go('/'),
          ),
        ],
      ),
    );
  }

  Widget _recapRow(GlassThemeData gt, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: gt.colors.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: gt.colors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: gt.colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 打字机标题
// ============================================================

class _TypewriterTitle extends StatefulWidget {
  const _TypewriterTitle({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_TypewriterTitle> createState() => _TypewriterTitleState();
}

class _TypewriterTitleState extends State<_TypewriterTitle> {
  String _displayed = '';
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayed = widget.text.substring(0, _charIndex);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayed, style: widget.style);
  }
}

// ============================================================
// 待生成态
// ============================================================

class _PendingRecap extends StatelessWidget {
  const _PendingRecap({required this.regenerating, required this.onRegenerate});

  final bool regenerating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'AI 正在为你生成回忆卡',
              style: TextStyle(
                color: gt.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '稍等片刻或手动触发',
              style: TextStyle(color: gt.colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            GlassButton(
              label: '生成回忆卡',
              icon: Icons.refresh,
              variant: GlassButtonVariant.secondary,
              isLoading: regenerating,
              onPressed: regenerating ? null : onRegenerate,
            ),
          ],
        ),
      ),
    );
  }
}
