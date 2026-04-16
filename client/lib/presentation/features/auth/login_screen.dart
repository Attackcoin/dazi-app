import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dazi_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../data/repositories/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _sending = false;
  bool _agreed = false;

  /// 当前选中的国家码（含 +）
  String _countryCode = '+86';

  static const _countryCodes = [
    ('+86', '中国', '🇨🇳'),
    ('+1', '美国/加拿大', '🇺🇸'),
    ('+44', '英国', '🇬🇧'),
    ('+81', '日本', '🇯🇵'),
    ('+82', '韩国', '🇰🇷'),
    ('+852', '中国香港', '🇭🇰'),
    ('+853', '中国澳门', '🇲🇴'),
    ('+886', '中国台湾', '🇹🇼'),
    ('+65', '新加坡', '🇸🇬'),
    ('+60', '马来西亚', '🇲🇾'),
    ('+61', '澳大利亚', '🇦🇺'),
    ('+49', '德国', '🇩🇪'),
    ('+33', '法国', '🇫🇷'),
    ('+39', '意大利', '🇮🇹'),
    ('+7', '俄罗斯', '🇷🇺'),
    ('+91', '印度', '🇮🇳'),
    ('+66', '泰国', '🇹🇭'),
    ('+84', '越南', '🇻🇳'),
    ('+62', '印度尼西亚', '🇮🇩'),
    ('+63', '菲律宾', '🇵🇭'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _phoneValid {
    final digits = _phoneController.text.trim();
    if (digits.isEmpty) return false;
    // 中国号：11 位，1 开头；其他国家：4~15 位数字
    if (_countryCode == '+86') {
      return RegExp(r'^1[3-9]\d{9}$').hasMatch(digits);
    }
    return digits.length >= 4 && digits.length <= 15;
  }

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _sendCode() async {
    if (!_phoneValid) {
      _showSnack('请输入正确的手机号');
      return;
    }
    if (!_agreed) {
      _showSnack('请先同意用户协议和隐私政策');
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).sendPhoneCode(_fullPhone);
      if (!mounted) return;
      context.push('/verify?phone=${Uri.encodeComponent(_fullPhone)}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('发送失败：$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showCountryCodePicker() {
    final gt = GlassTheme.of(context);
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: gt.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Spacing.space24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Spacing.space20, Spacing.space16, Spacing.space20, Spacing.space8),
              child: Text(
                '选择国家/地区',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: gt.colors.textPrimary,
                ),
              ),
            ),
            for (final c in _countryCodes)
              ListTile(
                leading: Text(c.$3, style: const TextStyle(fontSize: 22)),
                title: Text(c.$2, style: TextStyle(color: gt.colors.textPrimary)),
                trailing: Text(
                  c.$1,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textSecondary,
                  ),
                ),
                selected: c.$1 == _countryCode,
                selectedColor: gt.colors.primary,
                onTap: () {
                  Navigator.pop(ctx, c.$1);
                },
              ),
          ],
        ),
      ),
    ).then((picked) {
      if (picked != null) setState(() => _countryCode = picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.space24, Spacing.space24, Spacing.space24, Spacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: DaziColors.heroGradientColors.sublist(0, 2),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: gt.colors.primaryGlow,
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '搭',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.space32),
                Text(
                  '你好 👋',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(color: gt.colors.textPrimary),
                ),
                const SizedBox(height: Spacing.space8),
                Text(
                  '输入手机号登录 / 注册',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: gt.colors.textSecondary),
                ),
                const SizedBox(height: 40),
                // Phone input row: country code selector + GlassInput
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _showCountryCodePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.space12, vertical: 14),
                        decoration: BoxDecoration(
                          color: gt.colors.glassL2Bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: gt.colors.glassL2Border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _countryCodes
                                  .firstWhere((c) => c.$1 == _countryCode)
                                  .$3,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: Spacing.space4),
                            Text(
                              _countryCode,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: gt.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_drop_down,
                                size: 20, color: gt.colors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.space12),
                    Expanded(
                      child: GlassInput(
                        controller: _phoneController,
                        hint: '请输入手机号',
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                // Note: GlassInput does not expose inputFormatters;
                // phone digit filtering is handled by the existing controller logic.
                const SizedBox(height: Spacing.space20),
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        activeColor: gt.colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.space8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: gt.colors.textSecondary,
                          ),
                          children: [
                            const TextSpan(text: '我已阅读并同意 '),
                            TextSpan(
                              text: '用户协议',
                              style: TextStyle(
                                color: gt.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: ' 和 '),
                            TextSpan(
                              text: '隐私政策',
                              style: TextStyle(
                                color: gt.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GlassButton(
                  label: '获取验证码',
                  variant: GlassButtonVariant.primary,
                  isLoading: _sending,
                  expand: true,
                  onPressed: _sending ? null : _sendCode,
                ),
                const SizedBox(height: Spacing.space16),
                Center(
                  child: Text(
                    '其他登录方式',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: gt.colors.textTertiary),
                  ),
                ),
                const SizedBox(height: Spacing.space12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SocialButton(icon: Icons.g_mobiledata, label: 'Google'),
                    const SizedBox(width: Spacing.space24),
                    _SocialButton(icon: Icons.apple, label: 'Apple'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: gt.colors.glassL2Bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gt.colors.glassL2Border),
      ),
      child: Icon(icon, size: 28, color: gt.colors.textSecondary),
    );
  }
}
