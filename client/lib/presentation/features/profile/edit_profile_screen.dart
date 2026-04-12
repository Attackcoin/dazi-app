import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// 编辑资料页 —— 修改昵称 / 简介 / 兴趣标签 / 城市。
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final Set<String> _tags = {};
  bool _initialized = false;
  bool _saving = false;

  static const _allTags = [
    '咖啡', '美食', '徒步', '电影', '音乐', '桌游', '摄影',
    '运动', '旅行', '阅读', '艺术', '宠物', '游戏', '手作',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不能为空')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateProfile({
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'city': _cityController.text.trim(),
        'tags': _tags.toList(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final userAsync = ref.watch(currentAppUserProvider);
    final user = userAsync.valueOrNull;

    if (user != null && !_initialized) {
      _nameController.text = user.name;
      _bioController.text = user.bio;
      _cityController.text = user.city;
      _tags
        ..clear()
        ..addAll(user.tags);
      _initialized = true;
    }

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('编辑资料'),
        ),
        body: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(Spacing.space20),
                children: [
                  // 头像上传区
                  GlassCard(
                    level: 1,
                    padding: const EdgeInsets.all(Spacing.space20),
                    child: Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: gt.colors.glassL1Border,
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                          color: gt.colors.glassL2Bg,
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: gt.colors.textSecondary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.space16),
                  _label('昵称', gt),
                  GlassInput(
                    controller: _nameController,
                    hint: '请输入昵称',
                  ),
                  const SizedBox(height: Spacing.space16),
                  _label('个人简介', gt),
                  GlassInput(
                    controller: _bioController,
                    hint: '介绍一下你自己...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: Spacing.space16),
                  _label('城市', gt),
                  GlassInput(
                    controller: _cityController,
                    hint: '你所在的城市',
                  ),
                  const SizedBox(height: Spacing.space24),
                  _label('兴趣标签', gt),
                  const SizedBox(height: Spacing.space8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _allTags.map((t) {
                      final selected = _tags.contains(t);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _tags.remove(t);
                          } else {
                            _tags.add(t);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? gt.colors.primary
                                : gt.colors.glassL1Bg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? gt.colors.primary
                                  : gt.colors.glassL1Border,
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: selected
                                  ? gt.colors.textOnPrimary
                                  : gt.colors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: Spacing.space24),
                  GlassButton(
                    label: '保存',
                    variant: GlassButtonVariant.primary,
                    expand: true,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _label(String text, GlassThemeData gt) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: gt.colors.textPrimary,
          ),
        ),
      );
}
