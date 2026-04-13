import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/glass_theme.dart';

/// 二维码扫描器 —— 识别到合法 `dazi://checkin/...` payload 后回调。
class QrScanner extends StatefulWidget {
  const QrScanner({
    super.key,
    required this.expectedMatchId,
    required this.onDetected,
  });

  final String expectedMatchId;
  final void Function(String scannedUid) onDetected;

  @override
  State<QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final bc in capture.barcodes) {
      final raw = bc.rawValue;
      if (raw == null) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null || uri.scheme != 'dazi' || uri.host != 'checkin') {
        continue;
      }
      // path like "/{matchId}"
      final pathSegs = uri.pathSegments;
      if (pathSegs.isEmpty) continue;
      final scannedMatchId = pathSegs.first;
      if (scannedMatchId != widget.expectedMatchId) {
        _showError('这个二维码不属于当前搭子');
        continue;
      }
      final scannedUid = uri.queryParameters['uid'];
      if (scannedUid == null || scannedUid.isEmpty) continue;
      _handled = true;
      widget.onDetected(scannedUid);
      return;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GlassTheme.of(context).colors.primary, width: 2),
      ),
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.black54,
              child: const Text(
                '对准对方的签到二维码',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
