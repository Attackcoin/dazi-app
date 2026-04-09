import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
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
    final userAsync = ref.watch(currentAppUserProvider);
    final user = userAsync.valueOrNull;

    if (user != null && !_initialized) {
      _contacts
        ..clear()
        ..addAll(user.emergencyContacts.map((m) => Map<String, String>.from(m)));
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
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
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '见面遇到异常时，系统会通知这些联系人（最多 3 位）',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._contacts.asMap().entries.map((e) => _ContactTile(
                contact: e.value,
                onTap: () => _addOrEdit(index: e.key),
                onDelete: () => setState(() => _contacts.removeAt(e.key)),
              )),
          if (_contacts.length < 3)
            OutlinedButton.icon(
              onPressed: () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text('添加联系人'),
            ),
        ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceAlt,
          child: Icon(Icons.person, color: AppColors.textSecondary),
        ),
        title: Text(contact['name'] ?? ''),
        subtitle: Text(
          '${contact['relation'] ?? ''}  ${contact['phone'] ?? ''}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: onDelete,
        ),
        onTap: onTap,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '紧急联系人',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: '姓名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '电话'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _relationCtrl,
            decoration: const InputDecoration(labelText: '关系（如：父母、朋友）'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
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
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
