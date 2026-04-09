import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';

class StepNameAvatar extends StatefulWidget {
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
  State<StepNameAvatar> createState() => _StepNameAvatarState();
}

class _StepNameAvatarState extends State<StepNameAvatar> {
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('avatars/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('给自己起个名字', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text(
            '让搭子一眼记住你',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: AppColors.textSecondary),
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
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: ClipOval(
                      child: _uploading
                          ? const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : (widget.avatarUrl == null
                              ? const Icon(Icons.add_a_photo_outlined,
                                  size: 36, color: AppColors.textTertiary)
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
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
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
