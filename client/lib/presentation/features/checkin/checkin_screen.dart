import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
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

  Future<void> _submitCheckin({double? lat, double? lng}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final allDone = await ref.read(checkinRepositoryProvider).submit(
            matchId: widget.matchId,
            lat: lat,
            lng: lng,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allDone ? '双方已签到，搭子完成 🎉' : '签到成功 ✓ 等待对方签到'),
        ),
      );
      if (allDone) context.pop();
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
    final matchAsync = ref.watch(matchByIdProvider(widget.matchId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('签到'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '我的二维码'),
            Tab(text: '扫对方二维码'),
          ],
        ),
      ),
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (match) {
          if (match == null) return const Center(child: Text('搭子不存在'));
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
                      onScanned: (scannedUid) => _submitCheckin(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _gpsCheckin,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('GPS 签到（无法扫码时使用）'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.match, required this.myUid});

  final AppMatch match;
  final String myUid;

  @override
  Widget build(BuildContext context) {
    final meChecked = match.hasCheckedIn(myUid);
    final windowOpen = match.checkinWindowOpen;

    final (bg, icon, text) = switch ((windowOpen, meChecked, match.allCheckedIn)) {
      (false, _, _) => (
          Colors.amber.withValues(alpha: 0.15),
          Icons.access_time,
          '签到窗口未开启（见面时间后自动开启，持续 1 小时）',
        ),
      (true, _, true) => (
          AppColors.primary.withValues(alpha: 0.12),
          Icons.celebration,
          '双方都已签到，搭子完成！',
        ),
      (true, true, false) => (
          AppColors.primary.withValues(alpha: 0.12),
          Icons.check_circle,
          '你已签到 · 等待对方签到',
        ),
      (true, false, _) => (
          Colors.green.withValues(alpha: 0.12),
          Icons.radio_button_unchecked,
          '签到窗口进行中，请尽快完成签到',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: bg,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          QrScanner(
            expectedMatchId: match.id,
            onDetected: onScanned,
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '扫到对方二维码后会自动提交签到',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
