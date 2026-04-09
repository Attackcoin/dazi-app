import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _label('昵称'),
                TextField(
                  controller: _nameController,
                  maxLength: 20,
                  decoration: const InputDecoration(hintText: '请输入昵称'),
                ),
                const SizedBox(height: 16),
                _label('个人简介'),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  maxLength: 100,
                  decoration: const InputDecoration(hintText: '介绍一下你自己...'),
                ),
                const SizedBox(height: 16),
                _label('城市'),
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(hintText: '你所在的城市'),
                ),
                const SizedBox(height: 24),
                _label('兴趣标签'),
                const SizedBox(height: 8),
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
                              ? AppColors.primary
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}
