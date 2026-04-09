import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';

/// 本人的签到二维码 —— 编码为 `dazi://checkin/{matchId}?uid={uid}`。
class QrDisplay extends StatelessWidget {
  const QrDisplay({
    super.key,
    required this.matchId,
    required this.uid,
  });

  final String matchId;
  final String uid;

  String get _payload => 'dazi://checkin/$matchId?uid=$uid';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: QrImageView(
            data: _payload,
            version: QrVersions.auto,
            size: 220,
            gapless: false,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.primary,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '让对方扫一扫完成签到',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
