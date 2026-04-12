import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dazi_colors.dart';

/// 庆祝动画工具。通过静态方法在 Overlay 上展示。
class CelebrationOverlay {
  CelebrationOverlay._();

  /// 显示"加入成功"庆祝：✓ 弹出 + 脉冲光环 + 文字。
  static Future<void> showJoinSuccess(BuildContext context, {String? title}) async {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => _JoinSuccessAnimation(title: title));
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1800));
    entry.remove();
  }

  /// 显示"签到成功"庆祝：脉冲波纹 + ✓。
  static Future<void> showCheckinSuccess(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (_) => const _CheckinSuccessAnimation());
    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1500));
    entry.remove();
  }
}

class _JoinSuccessAnimation extends StatefulWidget {
  const _JoinSuccessAnimation({this.title});
  final String? title;

  @override
  State<_JoinSuccessAnimation> createState() => _JoinSuccessAnimationState();
}

class _JoinSuccessAnimationState extends State<_JoinSuccessAnimation> with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  late final Animation<double> _ring = Tween<double>(begin: 0, end: 1.5).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
  );
  late final Animation<double> _fade = Tween<double>(begin: 1, end: 0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.6, 1.0)),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: 0.3 * _fade.value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 脉冲光环
                      Transform.scale(
                        scale: _ring.value,
                        child: Opacity(
                          opacity: _fade.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DaziColors.heroGradientColors[1].withValues(alpha: 0.4),
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // ✓ 图标
                      ScaleTransition(
                        scale: _scale,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: DaziColors.heroGradientColors,
                            ),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 36),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FadeTransition(
                    opacity: _scale,
                    child: Text(
                      widget.title ?? '加入成功！',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckinSuccessAnimation extends StatefulWidget {
  const _CheckinSuccessAnimation();

  @override
  State<_CheckinSuccessAnimation> createState() => _CheckinSuccessAnimationState();
}

class _CheckinSuccessAnimationState extends State<_CheckinSuccessAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final pulse = Tween<double>(begin: 0, end: 2.0).animate(
          CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        );
        final fade = Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1.0)),
        );
        final check = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: 0.2 * fade.value),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Transform.scale(
                      scale: pulse.value - (i * 0.3),
                      child: Opacity(
                        opacity: (fade.value * (1 - i * 0.3)).clamp(0.0, 1.0),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ScaleTransition(
                    scale: check,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
