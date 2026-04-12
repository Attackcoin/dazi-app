import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/celebration_overlay.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/match.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/checkin_repository.dart';
import '../../../data/repositories/match_repository.dart';
import 'widgets/qr_display.dart';
import 'widgets/qr_scanner.dart';

/// 签到页 —— 我的二维码 / 扫对方二维码 / GPS 签到 三选一。
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _submitCheckin({double? lat, double? lng, String? scannedUid}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final allDone = await ref.read(checkinRepositoryProvider).submit(
            matchId: widget.matchId,
            lat: lat,
            lng: lng,
            scannedUid: scannedUid,
          );
      if (!mounted) return;
      if (allDone) {
        await CelebrationOverlay.showCheckinSuccess(context);
        if (mounted) context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('签到成功 ✓ 等待对方签到')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('签到失败：${_friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object e) {
    final match = RegExp(r'message: ([^,)]+)').firstMatch(e.toString());
    return match?.group(1) ?? e.toString();
  }

  Future<void> _gpsCheckin() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先开启定位服务')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('定位权限被拒绝')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _submitCheckin(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取位置失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('签到', style: TextStyle(color: gt.colors.textPrimary)),
          iconTheme: IconThemeData(color: gt.colors.textPrimary),
          bottom: TabBar(
            controller: _tabController,
            labelColor: gt.colors.primary,
            unselectedLabelColor: gt.colors.textSecondary,
            indicatorColor: gt.colors.primary,
            tabs: const [
              Tab(text: '我的二维码'),
              Tab(text: '扫对方二维码'),
            ],
          ),
        ),
        body: matchAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48,
                      color: gt.colors.textSecondary),
                  const SizedBox(height: 12),
                  Text('加载失败：$e', textAlign: TextAlign.center,
                      style: TextStyle(color: gt.colors.textPrimary)),
                  const SizedBox(height: 20),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.invalidate(matchByIdProvider(widget.matchId)),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          data: (match) {
            if (match == null) return Center(child: Text('搭子不存在', style: TextStyle(color: gt.colors.textPrimary)));
            return Column(
              children: [
                _StatusBanner(match: match, myUid: uid),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _MyQrPane(match: match, uid: uid),
                      _ScanPane(
                        match: match,
                        onScanned: (scannedUid) => _submitCheckin(scannedUid: scannedUid),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      GlassButton(
                        label: 'GPS 签到（无法扫码时使用）',
                        icon: Icons.my_location,
                        variant: GlassButtonVariant.primary,
                        expand: true,
                        isLoading: _submitting,
                        onPressed: _submitting ? null : _gpsCheckin,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusBanner extends StatefulWidget {
  const _StatusBanner({required this.match, required this.myUid});

  final AppMatch match;
  final String myUid;

  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final match = widget.match;
    final myUid = widget.myUid;
    final meChecked = match.hasCheckedIn(myUid);
    final windowOpen = match.checkinWindowOpen;

    // Determine banner state
    final isGpsActive = windowOpen && !meChecked && !match.allCheckedIn;

    final (bgColor, icon, text) = switch ((windowOpen, meChecked, match.allCheckedIn)) {
      (false, _, _) => (
          gt.colors.starColor.withValues(alpha: 0.15),
          Icons.access_time,
          '签到窗口未开启（见面时间后自动开启，持续 1 小时）',
        ),
      (true, _, true) => (
          gt.colors.primary.withValues(alpha: 0.12),
          Icons.celebration,
          '双方都已签到，搭子完成！',
        ),
      (true, true, false) => (
          gt.colors.primary.withValues(alpha: 0.12),
          Icons.check_circle,
          '你已签到 · 等待对方签到',
        ),
      (true, false, _) => (
          gt.colors.success.withValues(alpha: 0.12),
          Icons.radio_button_unchecked,
          '签到窗口进行中，请尽快完成签到',
        ),
    };

    return GlassCard(
      level: 1,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          isGpsActive
              ? AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Opacity(
                    opacity: 0.4 + 0.6 * _pulseCtrl.value,
                    child: Icon(icon, size: 18, color: gt.colors.info),
                  ),
                )
              : Icon(icon, size: 18, color: gt.colors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: gt.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyQrPane extends StatelessWidget {
  const _MyQrPane({required this.match, required this.uid});

  final AppMatch match;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: QrDisplay(matchId: match.id, uid: uid),
      ),
    );
  }
}

class _ScanPane extends StatelessWidget {
  const _ScanPane({required this.match, required this.onScanned});

  final AppMatch match;
  final void Function(String scannedUid) onScanned;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrScanner(
            expectedMatchId: match.id,
            onDetected: onScanned,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '扫到对方二维码后会自动提交签到',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: gt.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
