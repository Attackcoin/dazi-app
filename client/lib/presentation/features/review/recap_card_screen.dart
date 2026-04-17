import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/error_retry_view.dart';
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
        SnackBar(content: Text(AppLocalizations.of(context)!.recap_generateFailed('$e'))),
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
                  SnackBar(content: Text(AppLocalizations.of(context)!.recap_shareNotReady)),
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
            error: (e, _) => ErrorRetryView(
              error: e,
              onRetry: () =>
                  ref.invalidate(matchByIdProvider(widget.matchId)),
            ),
            data: (match) {
              if (match == null) {
                return Center(
                  child: Text(AppLocalizations.of(context)!.recap_matchNotExist,
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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
      child: Column(
        children: [
          _TypewriterTitle(
            text: '✨ ${l10n.recap_title}',
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
                _recapRow(gt, Icons.local_activity_outlined, l10n.recap_activity, recap.activity),
                const SizedBox(height: 12),
                _recapRow(gt, Icons.location_on_outlined, l10n.recap_location, recap.location),
                const SizedBox(height: 12),
                _recapRow(
                  gt,
                  Icons.group_outlined,
                  l10n.recap_participants,
                  l10n.recap_participantsCount(recap.participants),
                ),
                if (recap.duration != null) ...[
                  const SizedBox(height: 12),
                  _recapRow(
                    gt,
                    Icons.schedule,
                    l10n.recap_duration,
                    l10n.recap_durationMinutes(recap.duration!),
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
            label: l10n.recap_backToSquare,
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
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              l10n.recap_aiGenerating,
              style: TextStyle(
                color: gt.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.recap_waitOrTrigger,
              style: TextStyle(color: gt.colors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 32),
            GlassButton(
              label: l10n.recap_generateButton,
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
