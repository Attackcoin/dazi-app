import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/post.dart';
import '../../../../data/repositories/application_repository.dart';

/// 底部申请弹层 —— 展示活动摘要，用户点击「确认申请」后调用 Cloud Function。
class ApplySheet extends ConsumerStatefulWidget {
  const ApplySheet({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<ApplySheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(applicationRepositoryProvider)
          .applyToPost(widget.post.id);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    // FirebaseFunctionsException 里的 message 在 Cloud Function 中是中文
    final match = RegExp(r'message: ([^,)]+)').firstMatch(msg);
    if (match != null) return match.group(1) ?? msg;
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isFull = post.isFull;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isFull ? '加入候补名单' : '确认申请',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFull
                    ? '当前活动已满员，加入候补后若有空位会自动递补'
                    : '发布者会在 24 小时内回复你的申请',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sheetInfo(
                      Icons.schedule,
                      post.time == null
                          ? '时间待定'
                          : DateFormat('M月d日 HH:mm').format(post.time!),
                    ),
                    const SizedBox(height: 4),
                    _sheetInfo(
                      Icons.location_on_outlined,
                      post.location?.name ?? '地点待定',
                    ),
                    const SizedBox(height: 4),
                    _sheetInfo(
                      Icons.group_outlined,
                      '${post.acceptedCount}/${post.totalSlots} 人',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isFull ? '加入候补' : '确认申请'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 展示弹层的便捷方法。返回 [ApplyResult] 或 null（用户取消）。
Future<ApplyResult?> showApplySheet(BuildContext context, Post post) {
  return showModalBottomSheet<ApplyResult?>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => ApplySheet(post: post),
  );
}
