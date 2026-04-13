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

/// 紧急联系人页 —— 最多 3 位，用于见面时的紧急情况通知。
class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  ConsumerState<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends ConsumerState<EmergencyContactsScreen> {
  final List<Map<String, String>> _contacts = [];
  bool _initialized = false;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .setEmergencyContacts(_contacts);
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

  Future<void> _addOrEdit({int? index}) async {
    final existing = index != null ? _contacts[index] : null;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactEditSheet(initial: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _contacts[index] = result;
      } else {
        _contacts.add(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final userAsync = ref.watch(currentAppUserProvider);
    final user = userAsync.valueOrNull;

    if (user != null && !_initialized) {
      _contacts
        ..clear()
        ..addAll(user.emergencyContacts.map((m) => Map<String, String>.from(m)));
      _initialized = true;
    }

    return GlowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('紧急联系人'),
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
        body: ListView(
          padding: const EdgeInsets.all(Spacing.space20),
          children: [
            // 提示信息
            GlassCard(
              level: 1,
              padding: const EdgeInsets.all(Spacing.space12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: gt.colors.primary,
                  ),
                  const SizedBox(width: Spacing.space8),
                  Expanded(
                    child: Text(
                      '见面遇到异常时，系统会通知这些联系人（最多 3 位）',
                      style: TextStyle(
                        fontSize: 12,
                        color: gt.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.space16),
            ..._contacts.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.space8),
                  child: _ContactTile(
                    contact: e.value,
                    onTap: () => _addOrEdit(index: e.key),
                    onDelete: () => setState(() => _contacts.removeAt(e.key)),
                  ),
                )),
            if (_contacts.length < 3)
              GlassButton(
                label: '添加联系人',
                variant: GlassButtonVariant.secondary,
                icon: Icons.add,
                expand: true,
                onPressed: () => _addOrEdit(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, String> contact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    return GlassCard(
      level: 1,
      onTap: onTap,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: gt.colors.glassL2Bg,
          child: Icon(Icons.person, color: gt.colors.textSecondary),
        ),
        title: Text(
          contact['name'] ?? '',
          style: TextStyle(color: gt.colors.textPrimary),
        ),
        subtitle: Text(
          '${contact['relation'] ?? ''}  ${contact['phone'] ?? ''}',
          style: TextStyle(color: gt.colors.textSecondary),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: gt.colors.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _ContactEditSheet extends StatefulWidget {
  const _ContactEditSheet({this.initial});

  final Map<String, String>? initial;

  @override
  State<_ContactEditSheet> createState() => _ContactEditSheetState();
}

class _ContactEditSheetState extends State<_ContactEditSheet> {
  late final _nameCtrl =
      TextEditingController(text: widget.initial?['name'] ?? '');
  late final _phoneCtrl =
      TextEditingController(text: widget.initial?['phone'] ?? '');
  late final _relationCtrl =
      TextEditingController(text: widget.initial?['relation'] ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _relationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return GlassCard(
      level: 1,
      useBlur: true,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      padding: EdgeInsets.fromLTRB(
        Spacing.space20,
        Spacing.space20,
        Spacing.space20,
        Spacing.space20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '紧急联系人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: gt.colors.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.space16),
          GlassInput(
            controller: _nameCtrl,
            label: '姓名',
            hint: '请输入姓名',
          ),
          const SizedBox(height: Spacing.space12),
          GlassInput(
            controller: _phoneCtrl,
            label: '电话',
            hint: '请输入电话号码',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: Spacing.space12),
          GlassInput(
            controller: _relationCtrl,
            label: '关系',
            hint: '如：父母、朋友',
          ),
          const SizedBox(height: Spacing.space20),
          GlassButton(
            label: '确定',
            variant: GlassButtonVariant.primary,
            expand: true,
            onPressed: () {
              if (_nameCtrl.text.trim().isEmpty ||
                  _phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('姓名和电话必填')),
                );
                return;
              }
              Navigator.of(context).pop({
                'name': _nameCtrl.text.trim(),
                'phone': _phoneCtrl.text.trim(),
                'relation': _relationCtrl.text.trim(),
              });
            },
          ),
        ],
      ),
    );
  }
}
