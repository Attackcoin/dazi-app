import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/dazi_colors.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/widgets/celebration_overlay.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_input.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/models/category_config.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/application_repository.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/post_create_repository.dart';
import '../../../data/services/location_service.dart';

part 'create_post_quota.dart';

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
  bool _locating = false;

  // 系列活动
  bool _isSeriesMode = false;
  String _seriesRecurrence = 'weekly'; // "weekly" | "biweekly"
  int _seriesTotalWeeks = 4;

  List<CategoryConfig> _categories = const [];

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

  /// T5-04 GeoSearch: 使用 geolocator 获取当前位置，自动填充 locationName + lat/lng + city。
  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final locService = ref.read(locationServiceProvider);
      final result = await locService.getCurrentCity();
      if (!mounted) return;
      if (result == null) {
        final l10n = AppLocalizations.of(context)!;
        _showSnack(l10n.location_permissionDenied);
        return;
      }
      setState(() {
        _locationController.text = result.city;
        _draft.locationName = result.city;
        _draft.city = result.city;
        _draft.locationLat = result.lat;
        _draft.locationLng = result.lng;
      });
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.location_permissionDenied);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _publish() async {
    // debounce：防止按钮短时间内重复触发
    if (_publishing) return;

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

      // 并行上传图片。逐张捕获错误，任一失败就整体中止并提示具体哪张
      if (_pendingImages.isNotEmpty) {
        try {
          final uploads = <Future<String>>[];
          for (var i = 0; i < _pendingImages.length; i++) {
            final idx = i;
            uploads.add(
              repo.uploadImage(_pendingImages[idx]).catchError((Object e) {
                throw _ImageUploadException(idx + 1, e);
              }),
            );
          }
          _draft.imageUrls = await Future.wait(uploads, eagerError: true);
        } on _ImageUploadException catch (e) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          _showSnack(l10n.createPost_imageUploadFailed(e.index, _friendlyError(e.cause)));
          return;
        }
      }

      String postId;
      if (_isSeriesMode) {
        final result = await repo.createSeries(
          draft: _draft,
          recurrence: _seriesRecurrence,
          totalWeeks: _seriesTotalWeeks,
        );
        final postIds = (result['postIds'] as List?)?.cast<String>() ?? [];
        postId = postIds.isNotEmpty ? postIds.first : '';
      } else {
        postId = await repo.publish(_draft);
      }
      if (!mounted) return;
      final l10nSuccess = AppLocalizations.of(context)!;
      await CelebrationOverlay.showJoinSuccess(context, title: l10nSuccess.createPost_publishSuccess);
      if (!mounted) return;
      if (postId.isNotEmpty) {
        context.pushReplacement('/post/$postId');
      } else {
        context.pop();
      }
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final l10nErr = AppLocalizations.of(context)!;
      _showSnack(l10nErr.createPost_publishFailed(_friendlyFirebaseError(e)));
    } catch (e) {
      if (!mounted) return;
      final l10nErr = AppLocalizations.of(context)!;
      _showSnack(l10nErr.createPost_publishFailed(_friendlyError(e)));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  String _friendlyFirebaseError(FirebaseException e) {
    final l10n = AppLocalizations.of(context)!;
    switch (e.code) {
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return l10n.createPost_networkUnavailable;
      case 'permission-denied':
        return l10n.createPost_permissionDenied;
      case 'unauthenticated':
        return l10n.createPost_tokenExpired;
      default:
        return e.message ?? e.code;
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseException) return _friendlyFirebaseError(e);
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Network is unreachable')) {
      final l10n = AppLocalizations.of(context)!;
      return l10n.createPost_networkUnavailable;
    }
    return msg;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 弹出语音文字对话框 —— 用户把想说的话输入后，调用 Cloud Function 解析成字段。
  /// TODO: 后续接入平台 STT（speech_to_text），这里先用手动文字输入降级。
  Future<void> _showVoiceDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.createPost_voiceDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.createPost_voiceDialogHint,
              style: TextStyle(
                fontSize: 12,
                color: GlassTheme.of(ctx).colors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.createPost_voiceDialogPlaceholder,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.createPost_voiceDialogCancel),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.createPost_voiceDialogParse),
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
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.createPost_voiceFilled);
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      _showSnack(l10n.createPost_voiceParseFailed('$e'));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  void _applyVoiceResult(Map<String, dynamic> data) {
    setState(() {
      // category 可能是 "吃喝>喝咖啡"，取一级
      final rawCat = (data['category'] as String?) ?? '';
      final topCat = rawCat.split('>').first.trim();
      if (_categories.any((c) => c.id == topCat)) {
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
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnack(l10n.createPost_selectTitleFirst);
      return;
    }
    if (_draft.category.isEmpty) {
      _showSnack(l10n.createPost_selectCategoryFirst);
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
        _showSnack(l10n.createPost_descGenerated);
      }
    } catch (e) {
      _showSnack(l10n.createPost_descGenerateFailed('$e'));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final colors = gt.colors;
    // 订阅 categoriesProvider —— 之前用 ref.read 导致 stream 未到达时永远为空，
    // 且 UI 不会因为流后续 emit 而重建。
    _categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: colors.base,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(l10n.createPost_title),
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
            label: Text(l10n.createPost_voiceButton),
          ),
        ],
      ),
      body: GlowBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(l10n.createPost_categoryRequired, colors),
              _buildCategoryPicker(colors),
              _sectionLabel(l10n.createPost_titleRequired, colors),
              GlassInput(
                controller: _titleController,
                hint: l10n.createPost_titleHint,
              ),
              _sectionLabel(l10n.createPost_imageLabel, colors),
              _buildImagePicker(colors),
              _sectionLabel(l10n.createPost_timeRequired, colors),
              _buildTimePicker(colors),
              const SizedBox(height: 8),
              _buildSeriesSection(colors),
              _sectionLabel(l10n.createPost_locationRequired, colors),
              GlassInput(
                controller: _locationController,
                hint: l10n.createPost_locationHint,
                prefix: Icon(Icons.location_on_outlined, color: colors.textSecondary),
                suffix: _locating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(Icons.my_location, color: colors.primary, size: 20),
                        tooltip: l10n.location_useCurrentLocation,
                        onPressed: _useCurrentLocation,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
              ),
              _sectionLabel(l10n.createPost_slotsLabel, colors),
              _buildSlotsPicker(colors),
              const SizedBox(height: 10),
              _buildGenderQuotaSection(),
              _sectionLabel(l10n.createPost_costTypeLabel, colors),
              _buildCostTypePicker(colors),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Row(
                  children: [
                    Text(
                      l10n.createPost_descOptional,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
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
                      label: Text(l10n.createPost_aiGenerateDesc,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              GlassInput(
                controller: _descController,
                maxLines: 4,
                hint: l10n.createPost_descHint,
              ),
              const SizedBox(height: 8),
              _buildSocialAnxietyToggle(colors),
              const SizedBox(height: 8),
              _buildWomenOnlyToggle(colors),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.glassL1Border, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: GlassButton(
            label: l10n.createPost_publishButton,
            variant: GlassButtonVariant.primary,
            expand: true,
            isLoading: _publishing,
            onPressed: _publishing ? null : _publish,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, DaziColorScheme colors) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      );

  Widget _buildCategoryPicker(DaziColorScheme colors) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((c) {
        final selected = _draft.category == c.id;
        return PillTag(
          label: '${c.emoji} ${c.label}',
          selected: selected,
          onTap: () => setState(() => _draft.category = c.id),
        );
      }).toList(),
    );
  }

  Widget _buildImagePicker(DaziColorScheme colors) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingImages.length + (_pendingImages.length < 6 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          if (i == _pendingImages.length) {
            return Semantics(
              button: true,
              label: '添加图片',
              child: GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 88,
                  decoration: BoxDecoration(
                    color: colors.glassL1Bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.glassL1Border,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: colors.textTertiary),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.createPost_addImage,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
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
                child: Semantics(
                  button: true,
                  label: '删除图片',
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimePicker(DaziColorScheme colors) {
    final hasTime = _draft.time != null;
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: _pickTime,
      child: Row(
        children: [
          Icon(Icons.schedule, color: colors.textSecondary),
          const SizedBox(width: 12),
          Text(
            hasTime
                ? DateFormat('M月d日 HH:mm').format(_draft.time!)
                : l10n.createPost_pickTimeLabel,
            style: TextStyle(
              fontSize: 15,
              color: hasTime
                  ? colors.textPrimary
                  : colors.textTertiary,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, color: colors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildSlotsPicker(DaziColorScheme colors) {
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: [
          Text(AppLocalizations.of(context)!.createPost_totalSlots, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: colors.primary,
            onPressed: _draft.totalSlots > 2
                ? () => setState(() => _draft.totalSlots--)
                : null,
          ),
          Text(
            '${_draft.totalSlots}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: colors.primary,
            onPressed: _draft.totalSlots < 50
                ? () => setState(() => _draft.totalSlots++)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCostTypePicker(DaziColorScheme colors) {
    final l10n = AppLocalizations.of(context)!;
    String costLabel(CostType ct) => switch (ct) {
      CostType.aa => l10n.costType_aa,
      CostType.host => l10n.costType_host,
      CostType.self => l10n.costType_self,
      CostType.tbd => l10n.costType_tbd,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CostType.values.map((t) {
        final selected = _draft.costType == t;
        return PillTag(
          label: costLabel(t),
          selected: selected,
          onTap: () => setState(() => _draft.costType = t),
        );
      }).toList(),
    );
  }

  Widget _buildSocialAnxietyToggle(DaziColorScheme colors) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('🫣', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.createPost_socialAnxietyFriendly,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  l10n.createPost_socialAnxietySubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _draft.isSocialAnxietyFriendly,
            onChanged: (v) =>
                setState(() => _draft.isSocialAnxietyFriendly = v),
            activeColor: colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildWomenOnlyToggle(DaziColorScheme colors) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 1,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.female, size: 20, color: colors.accent),
                    const SizedBox(width: 6),
                    Text(
                      l10n.post_womenOnlyToggle,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.post_womenOnlyHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _draft.womenOnly,
            onChanged: (v) => setState(() => _draft.womenOnly = v),
            activeColor: colors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesSection(DaziColorScheme colors) {
    final l10n = AppLocalizations.of(context)!;
    return GlassCard(
      level: 1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u{1F4C5}', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.post_seriesToggle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.post_seriesHint(
                        _seriesTotalWeeks,
                        _seriesRecurrence == 'weekly'
                            ? l10n.post_seriesRecurrenceWeekly
                            : l10n.post_seriesRecurrenceBiweekly,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isSeriesMode,
                onChanged: (v) => setState(() => _isSeriesMode = v),
                activeColor: colors.primary,
              ),
            ],
          ),
          if (_isSeriesMode) ...[
            const SizedBox(height: 16),
            // 频率选择
            Text(
              l10n.post_seriesRecurrenceWeekly,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'weekly',
                  label: Text(l10n.post_seriesRecurrenceWeekly),
                ),
                ButtonSegment(
                  value: 'biweekly',
                  label: Text(l10n.post_seriesRecurrenceBiweekly),
                ),
              ],
              selected: {_seriesRecurrence},
              onSelectionChanged: (v) =>
                  setState(() => _seriesRecurrence = v.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colors.primary.withValues(alpha: 0.15),
                selectedForegroundColor: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            // 总周数
            Row(
              children: [
                Text(
                  l10n.post_seriesTotalWeeks(_seriesTotalWeeks),
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: colors.primary,
                  onPressed: _seriesTotalWeeks > 2
                      ? () => setState(() => _seriesTotalWeeks--)
                      : null,
                ),
                Text(
                  '$_seriesTotalWeeks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: colors.primary,
                  onPressed: _seriesTotalWeeks < 8
                      ? () => setState(() => _seriesTotalWeeks++)
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 内部异常：标记是哪一张图片上传失败（index 从 1 开始，用于提示）。
class _ImageUploadException implements Exception {
  _ImageUploadException(this.index, this.cause);
  final int index;
  final Object cause;

  @override
  String toString() => 'Image #$index upload failed: $cause';
}
