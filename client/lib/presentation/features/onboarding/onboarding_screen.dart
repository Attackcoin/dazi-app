import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/dazi_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/repositories/auth_repository.dart';
import 'widgets/step_city.dart';
import 'widgets/step_gender.dart';
import 'widgets/step_name_avatar.dart';
import 'widgets/step_tags.dart';
import 'widgets/step_year.dart';

/// 新用户注册引导 —— 5 步填完基本资料。
///
/// 页面之间用 PageView 切换，顶部进度条显示当前步数。
/// 所有字段累积在 OnboardingData 中，最后一步一次性写入 Firestore。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _submitting = false;
  final _data = OnboardingData();

  static const _totalSteps = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentStep == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _data.gender != null;
      case 1:
        return _data.name.trim().isNotEmpty;
      case 2:
        return _data.birthYear != null;
      case 3:
        return _data.tags.isNotEmpty;
      case 4:
        return _data.city.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _finish() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await ref.read(firestoreProvider).collection('users').doc(user.uid).update({
        'gender': _data.gender,
        'name': _data.name.trim(),
        'avatar': _data.avatarUrl ?? '',
        'birthYear': _data.birthYear,
        'tags': _data.tags,
        'city': _data.city.trim(),
        'isSocialAnxietyFriendly': _data.socialAnxietyMode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.common_saveFailed('$e'))),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(gt),
              const SizedBox(height: Spacing.space16),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    StepGender(
                      value: _data.gender,
                      onChanged: (v) => setState(() => _data.gender = v),
                    ),
                    StepNameAvatar(
                      name: _data.name,
                      avatarUrl: _data.avatarUrl,
                      onNameChanged: (v) => setState(() => _data.name = v),
                      onAvatarChanged: (v) => setState(() => _data.avatarUrl = v),
                    ),
                    StepYear(
                      value: _data.birthYear,
                      onChanged: (v) => setState(() => _data.birthYear = v),
                    ),
                    StepTags(
                      selected: _data.tags,
                      socialAnxietyMode: _data.socialAnxietyMode,
                      onTagsChanged: (v) => setState(() => _data.tags = v),
                      onSocialAnxietyChanged: (v) =>
                          setState(() => _data.socialAnxietyMode = v),
                    ),
                    StepCity(
                      value: _data.city,
                      onChanged: (v) => setState(() => _data.city = v),
                    ),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GlassThemeData gt) {
    final progress = (_currentStep + 1) / _totalSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.space24, Spacing.space16, Spacing.space24, 0),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new,
                  size: 20, color: gt.colors.textPrimary),
              onPressed: _back,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 20),
          const SizedBox(width: Spacing.space12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  // Track
                  Container(
                    height: 4,
                    color: gt.colors.glassL2Bg,
                  ),
                  // Fill — gradient
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: DaziColors.heroGradientColors,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: Spacing.space12),
          Text(
            '${_currentStep + 1}/$_totalSteps',
            style: TextStyle(
              fontSize: 13,
              color: gt.colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Spacing.space24, Spacing.space12, Spacing.space24, Spacing.space24),
      child: GlassButton(
        label: _currentStep == _totalSteps - 1 ? AppLocalizations.of(context)!.onboarding_complete : AppLocalizations.of(context)!.onboarding_nextStep,
        onPressed: (_canProceed && !_submitting) ? _next : null,
        variant: GlassButtonVariant.primary,
        isLoading: _submitting,
        expand: true,
      ),
    );
  }
}

/// 引导页收集的字段，最后一步一次性写入 Firestore。
class OnboardingData {
  String? gender;
  String name = '';
  String? avatarUrl;
  int? birthYear;
  List<String> tags = [];
  String city = '';
  bool socialAnxietyMode = false;
}
