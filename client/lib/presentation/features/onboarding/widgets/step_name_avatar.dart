import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/glass_theme.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../data/repositories/auth_repository.dart';

class StepNameAvatar extends ConsumerStatefulWidget {
  const StepNameAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.onNameChanged,
    required this.onAvatarChanged,
  });

  final String name;
  final String? avatarUrl;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onAvatarChanged;

  @override
  ConsumerState<StepNameAvatar> createState() => _StepNameAvatarState();
}

class _StepNameAvatarState extends ConsumerState<StepNameAvatar> {
  late final TextEditingController _controller;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final storage = ref.read(firebaseStorageProvider);
      final ref0 = storage.ref(
        'avatars/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref0.putFile(File(picked.path));
      final url = await ref0.getDownloadURL();
      widget.onAvatarChanged(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('给自己起个名字', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: Spacing.space8),
          Text(
            '让搭子一眼记住你',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: gt.colors.textSecondary),
          ),
          const SizedBox(height: 40),
          Center(
            child: GestureDetector(
              onTap: _uploading ? null : _pickAvatar,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: gt.colors.glassL2Bg,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: gt.colors.glassL2Border, width: 2),
                    ),
                    child: ClipOval(
                      child: _uploading
                          ? Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: gt.colors.primary),
                            )
                          : (widget.avatarUrl == null
                              ? Icon(Icons.add_a_photo_outlined,
                                  size: 36, color: gt.colors.textTertiary)
                              : CachedNetworkImage(
                                  imageUrl: widget.avatarUrl!,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                )),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: gt.colors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _controller,
            maxLength: 12,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(hintText: '输入你的昵称'),
            onChanged: widget.onNameChanged,
          ),
        ],
      ),
    );
  }
}
