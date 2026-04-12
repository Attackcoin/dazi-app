import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/repositories/auth_repository.dart';

class PhoneVerifyScreen extends ConsumerStatefulWidget {
  const PhoneVerifyScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends ConsumerState<PhoneVerifyScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_codeController.text.length != 6) return;
    setState(() => _verifying = true);
    try {
      await ref.read(authRepositoryProvider).verifyCode(_codeController.text);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('验证失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length < 6) return p;
    // 保留前段（国家码+前几位）和后 4 位，中间用 **** 替代
    final visibleEnd = p.substring(p.length - 4);
    final visibleStart = p.substring(0, p.length - 8 > 0 ? p.length - 8 : 3);
    return '$visibleStart****$visibleEnd';
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Scaffold(
      backgroundColor: gt.colors.base,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: gt.colors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: GlowBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.space24, Spacing.space24, Spacing.space24, Spacing.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Spacing.space16),
                Text(
                  '验证码已发送',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(color: gt.colors.textPrimary),
                ),
                const SizedBox(height: Spacing.space8),
                Text(
                  '已向 $_maskedPhone 发送 6 位验证码',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: gt.colors.textSecondary),
                ),
                const SizedBox(height: 40),
                GlassInput(
                  controller: _codeController,
                  hint: '------',
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  onChanged: (v) {
                    setState(() {});
                    if (v.length == 6) _submit();
                  },
                ),
                const SizedBox(height: Spacing.space16),
                // Countdown / resend hint
                Center(
                  child: Text(
                    '没收到验证码？稍后可重新发送',
                    style: TextStyle(
                      fontSize: 13,
                      color: gt.colors.textAccent,
                    ),
                  ),
                ),
                const Spacer(),
                GlassButton(
                  label: '验证并登录',
                  variant: GlassButtonVariant.primary,
                  isLoading: _verifying,
                  expand: true,
                  onPressed: _verifying || _codeController.text.length != 6
                      ? null
                      : _submit,
                ),
                const SizedBox(height: Spacing.space12),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      '没收到？重新发送',
                      style: TextStyle(color: gt.colors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
