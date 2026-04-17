import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/repositories/auth_repository.dart';

/// 设置邮箱+密码登录（绑定到已有手机账号）。
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // 如果已绑定邮箱，预填
    final repo = ref.read(authRepositoryProvider);
    final email = repo.linkedEmail;
    if (email != null) _emailController.text = email;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _emailValid {
    final email = _emailController.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool get _passwordValid => _passwordController.text.length >= 6;

  bool get _confirmMatch =>
      _passwordController.text == _confirmController.text;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_emailValid) {
      _showSnack(l10n.setPassword_emailInvalid);
      return;
    }
    if (!_passwordValid) {
      _showSnack(l10n.setPassword_passwordTooShort);
      return;
    }
    if (!_confirmMatch) {
      _showSnack(l10n.setPassword_passwordConfirmMismatch);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).linkEmailPassword(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      // 强制刷新 auth 状态，让 hasEmailProvider 生效
      ref.invalidate(authStateProvider);
      _showSnack(l10n.setPassword_success);
      // 短暂延迟让 rebuild 完成后再 setState
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {});
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'email-already-in-use' => l10n.setPassword_errorAlreadyInUse,
        'invalid-email' => l10n.setPassword_errorInvalidEmail,
        'provider-already-linked' => l10n.setPassword_errorAlreadyLinked,
        'weak-password' => l10n.setPassword_errorWeakPassword,
        'requires-recent-login' => l10n.setPassword_errorRecentLogin,
        _ => l10n.setPassword_errorDefault(e.message ?? e.code),
      };
      _showSnack(msg);
    } catch (e) {
      if (!mounted) return;
      _showSnack(l10n.setPassword_errorDefault('$e'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final alreadyLinked = ref.watch(authRepositoryProvider).hasEmailProvider;

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
        title: Text(
          l10n.setPassword_screenTitle,
          style: TextStyle(color: gt.colors.textPrimary, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: GlowBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (alreadyLinked) ...[
                  Container(
                    padding: const EdgeInsets.all(Spacing.space12),
                    decoration: BoxDecoration(
                      color: gt.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: gt.colors.primary, size: 20),
                        const SizedBox(width: Spacing.space8),
                        Expanded(
                          child: Text(
                            l10n.setPassword_alreadyBound(ref.read(authRepositoryProvider).linkedEmail ?? ''),
                            style: TextStyle(
                              color: gt.colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.space24),
                ],
                Text(
                  alreadyLinked ? l10n.setPassword_boundTitle : l10n.setPassword_bindTitle,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: gt.colors.textPrimary),
                ),
                const SizedBox(height: Spacing.space8),
                Text(
                  alreadyLinked
                      ? l10n.setPassword_boundSubtitle
                      : l10n.setPassword_unboundSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: gt.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: Spacing.space24),
                if (!alreadyLinked) ...[
                  GlassInput(
                    controller: _emailController,
                    hint: l10n.setPassword_emailHint,
                    label: l10n.setPassword_emailLabel,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    prefix: Icon(Icons.email_outlined,
                        size: 20, color: gt.colors.textTertiary),
                  ),
                  const SizedBox(height: Spacing.space16),
                  GlassInput(
                    controller: _passwordController,
                    hint: l10n.setPassword_passwordHint,
                    label: l10n.setPassword_passwordLabel,
                    obscureText: _obscurePassword,
                    onChanged: (_) => setState(() {}),
                    prefix: Icon(Icons.lock_outline,
                        size: 20, color: gt.colors.textTertiary),
                    suffix: GestureDetector(
                      onTap: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: gt.colors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.space16),
                  GlassInput(
                    controller: _confirmController,
                    hint: l10n.setPassword_confirmHint,
                    label: l10n.setPassword_confirmLabel,
                    obscureText: _obscureConfirm,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                    prefix: Icon(Icons.lock_outline,
                        size: 20, color: gt.colors.textTertiary),
                    suffix: GestureDetector(
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: gt.colors.textTertiary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GlassButton(
                    label: l10n.setPassword_confirmButton,
                    variant: GlassButtonVariant.primary,
                    isLoading: _saving,
                    expand: true,
                    onPressed: _saving ? null : _submit,
                  ),
                  const SizedBox(height: Spacing.space16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
