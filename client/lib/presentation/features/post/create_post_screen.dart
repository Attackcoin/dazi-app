import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/application_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/post_create_repository.dart';

/// 发布搭子表单页。
///
/// 按照 implementation-plan Task 9 的字段集合实现。
/// TODO: 语音 AI 发布、AI 写描述、地图选点（等 Maps API 接入后）。
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _draft = PostDraft();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  final List<File> _pendingImages = [];
  bool _publishing = false;
  bool _aiLoading = false;
  bool _genderQuotaEnabled = false;

  static const _categories = [
    ('吃喝', '🍜'),
    ('运动', '🏃'),
    ('文艺', '🎨'),
    ('旅行', '✈️'),
    ('学习', '📚'),
    ('游戏', '🎮'),
  ];

  @override
  void initState() {
    super.initState();
    // 默认用用户的城市
    final user = ref.read(currentAppUserProvider).valueOrNull;
    if (user != null) _draft.city = user.city;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
      limit: 6 - _pendingImages.length,
    );
    if (picked.isEmpty) return;
    setState(() {
      _pendingImages.addAll(picked.map((x) => File(x.path)));
    });
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) return;
    setState(() {
      _draft.time = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _publish() async {
    _draft.title = _titleController.text;
    _draft.description = _descController.text;
    _draft.locationName = _locationController.text;

    final error = _draft.validate();
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _publishing = true);
    try {
      final repo = ref.read(postCreateRepositoryProvider);

      // 并行上传图片
      if (_pendingImages.isNotEmpty) {
        final urls = await Future.wait(_pendingImages.map(repo.uploadImage));
        _draft.imageUrls = urls;
      }

      final postId = await repo.publish(_draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布成功 🎉')),
      );
      context.pushReplacement('/post/$postId');
    } catch (e) {
      if (!mounted) return;
      _showSnack('发布失败：$e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 弹出语音文字对话框 —— 用户把想说的话输入后，调用 Cloud Function 解析成字段。
  /// TODO: 后续接入平台 STT（speech_to_text），这里先用手动文字输入降级。
  Future<void> _showVoiceDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语音发布'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '说一句话，AI 会自动提取分类 / 标题 / 时间 / 地点等。',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '例如：周六下午三点去外滩喝咖啡，找两个人一起',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('解析'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    await _callParseVoice(text);
  }

  Future<void> _callParseVoice(String text) async {
    setState(() => _aiLoading = true);
    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final result = await functions
          .httpsCallable('parseVoicePost')
          .call<Map<String, dynamic>>({'text': text});
      final payload = Map<String, dynamic>.from(result.data);
      if (payload['success'] != true) {
        throw StateError(payload['error']?.toString() ?? '解析失败');
      }
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      _applyVoiceResult(data);
      _showSnack('已填充，请检查后发布');
    } catch (e) {
      _showSnack('语音解析失败：$e');
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _applyVoiceResult(Map<String, dynamic> data) {
    setState(() {
      // category 可能是 "吃喝>喝咖啡"，取一级
      final rawCat = (data['category'] as String?) ?? '';
      final topCat = rawCat.split('>').first.trim();
      if (_categories.any((c) => c.$1 == topCat)) {
        _draft.category = topCat;
      }

      final title = (data['title'] as String?) ?? '';
      if (title.isNotEmpty) {
        _titleController.text = title;
        _draft.title = title;
      }

      final loc = (data['location'] as String?) ?? '';
      if (loc.isNotEmpty) {
        _locationController.text = loc;
        _draft.locationName = loc;
      }

      final slots = (data['totalSlots'] as num?)?.toInt();
      if (slots != null && slots >= 2 && slots <= 50) {
        _draft.totalSlots = slots;
      }

      final ct = (data['costType'] as String?) ?? '';
      if (ct.isNotEmpty) {
        _draft.costType = CostType.fromString(ct);
      }

      final desc = (data['suggestedDescription'] as String?) ?? '';
      if (desc.isNotEmpty) {
        _descController.text = desc;
        _draft.description = desc;
      }
      // timeText 留空 —— 自然语言时间让用户手动确认
    });
  }

  Future<void> _generateDescription() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack('请先填写标题');
      return;
    }
    if (_draft.category.isEmpty) {
      _showSnack('请先选择分类');
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final result = await functions
          .httpsCallable('generateDescription')
          .call<Map<String, dynamic>>({
        'title': title,
        'category': _draft.category,
      });
      final payload = Map<String, dynamic>.from(result.data);
      final desc = (payload['description'] as String?) ?? '';
      if (desc.isNotEmpty) {
        setState(() {
          _descController.text = desc;
          _draft.description = desc;
        });
        _showSnack('已生成描述');
      }
    } catch (e) {
      _showSnack('生成失败：$e');
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布搭子'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: _aiLoading ? null : _showVoiceDialog,
            icon: _aiLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mic, size: 18),
            label: const Text('语音'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('分类 *'),
            _buildCategoryPicker(),
            _sectionLabel('标题 *'),
            TextField(
              controller: _titleController,
              maxLength: 30,
              decoration: const InputDecoration(
                hintText: '例如：周末去静安寺喝咖啡',
              ),
            ),
            _sectionLabel('图片（可选，最多 6 张）'),
            _buildImagePicker(),
            _sectionLabel('时间 *'),
            _buildTimePicker(),
            _sectionLabel('地点 *'),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: '例如：星巴克臻选·太古汇店',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            _sectionLabel('人数'),
            _buildSlotsPicker(),
            const SizedBox(height: 10),
            _buildGenderQuotaSection(),
            _sectionLabel('费用方式'),
            _buildCostTypePicker(),
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              child: Row(
                children: [
                  const Text(
                    '描述（可选）',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _aiLoading ? null : _generateDescription,
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 帮写',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _descController,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: '介绍一下活动，吸引同好报名',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            _buildSocialAnxietyToggle(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('发布'),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((c) {
        final selected = _draft.category == c.$1;
        return GestureDetector(
          onTap: () => setState(() => _draft.category = c.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c.$2, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  c.$1,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImagePicker() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingImages.length + (_pendingImages.length < 6 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == _pendingImages.length) {
            return GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 88,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.textTertiary),
                    SizedBox(height: 4),
                    Text(
                      '添加',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _pendingImages[i],
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _pendingImages.removeAt(i)),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimePicker() {
    final hasTime = _draft.time != null;
    return InkWell(
      onTap: _pickTime,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              hasTime
                  ? DateFormat('M月d日 HH:mm').format(_draft.time!)
                  : '选择活动时间',
              style: TextStyle(
                fontSize: 15,
                color: hasTime
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotsPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('总人数', style: TextStyle(fontSize: 14)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
            onPressed: _draft.totalSlots > 2
                ? () => setState(() => _draft.totalSlots--)
                : null,
          ),
          Text(
            '${_draft.totalSlots}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
            onPressed: _draft.totalSlots < 50
                ? () => setState(() => _draft.totalSlots++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderQuotaSection() {
    final male = _draft.maleQuota ?? 0;
    final female = _draft.femaleQuota ?? 0;
    final total = _draft.totalSlots;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('性别配额', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Text(
                '（可选）',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              const Spacer(),
              Switch(
                value: _genderQuotaEnabled,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() {
                  _genderQuotaEnabled = v;
                  if (v) {
                    _draft.maleQuota = (total / 2).floor();
                    _draft.femaleQuota = total - _draft.maleQuota!;
                  } else {
                    _draft.maleQuota = null;
                    _draft.femaleQuota = null;
                  }
                }),
              ),
            ],
          ),
          if (_genderQuotaEnabled) ...[
            _quotaSlider(
              label: '男生',
              icon: Icons.male,
              value: male,
              total: total,
              onChanged: (v) => setState(() {
                _draft.maleQuota = v;
                if (v + (_draft.femaleQuota ?? 0) > total) {
                  _draft.femaleQuota = total - v;
                }
              }),
            ),
            _quotaSlider(
              label: '女生',
              icon: Icons.female,
              value: female,
              total: total,
              onChanged: (v) => setState(() {
                _draft.femaleQuota = v;
                if (v + (_draft.maleQuota ?? 0) > total) {
                  _draft.maleQuota = total - v;
                }
              }),
            ),
            Text(
              '合计 ${male + female} / $total',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quotaSlider({
    required String label,
    required IconData icon,
    required int value,
    required int total,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        SizedBox(
          width: 32,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: total.toDouble(),
            divisions: total,
            label: '$value',
            activeColor: AppColors.primary,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCostTypePicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CostType.values.map((t) {
        final selected = _draft.costType == t;
        return GestureDetector(
          onTap: () => setState(() => _draft.costType = t),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              t.label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSocialAnxietyToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🫣', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '社恐友好',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '小群 / 不强迫自我介绍',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _draft.isSocialAnxietyFriendly,
            onChanged: (v) =>
                setState(() => _draft.isSocialAnxietyFriendly = v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
