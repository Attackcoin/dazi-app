import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../data/models/voice_room.dart';
import '../../../data/repositories/voice_room_repository.dart';

/// 语音房列表页。
class VoiceRoomsScreen extends ConsumerWidget {
  const VoiceRoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final roomsAsync = ref.watch(liveVoiceRoomsProvider);

    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              title: Text(l10n.voice_title),
              centerTitle: false,
              floating: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: l10n.voice_createTitle,
                  onPressed: () => _showCreateSheet(context, ref),
                ),
              ],
            ),
            roomsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Text(
                    l10n.common_loadFailed,
                    style: TextStyle(color: gt.colors.textSecondary),
                  ),
                ),
              ),
              data: (rooms) {
                if (rooms.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_off_outlined,
                              size: 64, color: gt.colors.textTertiary),
                          const SizedBox(height: Spacing.space12),
                          Text(
                            l10n.voice_emptyList,
                            style: TextStyle(color: gt.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space16,
                    vertical: Spacing.space8,
                  ),
                  sliver: SliverList.separated(
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: Spacing.space12),
                    itemBuilder: (context, index) =>
                        _VoiceRoomCard(room: rooms[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateVoiceRoomSheet(),
    );
  }
}

class _VoiceRoomCard extends StatelessWidget {
  const _VoiceRoomCard({required this.room});
  final VoiceRoom room;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return GlassCard(
      onTap: () => context.push('/voice/${room.id}'),
      padding: const EdgeInsets.all(Spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 直播指示器
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: gt.colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Spacing.space8),
              Expanded(
                child: Text(
                  room.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: gt.colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.space8),
              // 人数
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space8, vertical: 2),
                decoration: BoxDecoration(
                  color: gt.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        size: 14, color: gt.colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.voice_participants(
                          room.participantCount, room.maxParticipants),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (room.topic.isNotEmpty) ...[
            const SizedBox(height: Spacing.space8),
            Text(
              room.topic,
              style: TextStyle(
                fontSize: 13,
                color: gt.colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Spacing.space8),
          // 主持人信息
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: gt.colors.primary.withValues(alpha: 0.15),
                backgroundImage: room.hostAvatar.isNotEmpty
                    ? NetworkImage(room.hostAvatar)
                    : null,
                child: room.hostAvatar.isEmpty
                    ? Icon(Icons.mic, size: 14, color: gt.colors.primary)
                    : null,
              ),
              const SizedBox(width: Spacing.space4),
              Text(
                room.hostName.isNotEmpty ? room.hostName : l10n.voice_host,
                style: TextStyle(
                  fontSize: 12,
                  color: gt.colors.textTertiary,
                ),
              ),
              if (room.category.isNotEmpty) ...[
                const SizedBox(width: Spacing.space8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: gt.colors.glassL2Bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gt.colors.glassL2Border),
                  ),
                  child: Text(
                    room.category,
                    style: TextStyle(
                      fontSize: 10,
                      color: gt.colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 创建语音房的底部弹窗。
class _CreateVoiceRoomSheet extends ConsumerStatefulWidget {
  const _CreateVoiceRoomSheet();

  @override
  ConsumerState<_CreateVoiceRoomSheet> createState() =>
      _CreateVoiceRoomSheetState();
}

class _CreateVoiceRoomSheetState extends ConsumerState<_CreateVoiceRoomSheet> {
  final _titleCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  int _maxParticipants = 8;
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final roomId = await ref.read(voiceRoomRepositoryProvider).createRoom(
            title: title,
            topic: _topicCtrl.text.trim(),
            maxParticipants: _maxParticipants,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voice_createSuccess)),
      );
      context.push('/voice/$roomId');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voice_createFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassCard(
        level: 2,
        useBlur: true,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.sheet),
        ),
        padding: const EdgeInsets.all(Spacing.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: gt.colors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space16),
            Text(
              l10n.voice_createTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: gt.colors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.space16),
            // 标题
            TextField(
              controller: _titleCtrl,
              maxLength: 50,
              style: TextStyle(color: gt.colors.textPrimary),
              decoration: InputDecoration(
                labelText: l10n.voice_createName,
                hintText: l10n.voice_createNameHint,
                labelStyle: TextStyle(color: gt.colors.textSecondary),
                hintStyle: TextStyle(color: gt.colors.textTertiary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                  borderSide: BorderSide(color: gt.colors.glassL2Border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                  borderSide: BorderSide(color: gt.colors.primary),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space12),
            // 话题
            TextField(
              controller: _topicCtrl,
              maxLength: 200,
              maxLines: 2,
              style: TextStyle(color: gt.colors.textPrimary),
              decoration: InputDecoration(
                labelText: l10n.voice_createTopic,
                hintText: l10n.voice_createTopicHint,
                labelStyle: TextStyle(color: gt.colors.textSecondary),
                hintStyle: TextStyle(color: gt.colors.textTertiary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                  borderSide: BorderSide(color: gt.colors.glassL2Border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.input),
                  borderSide: BorderSide(color: gt.colors.primary),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space12),
            // 最大人数
            Row(
              children: [
                Text(
                  l10n.voice_createMaxParticipants,
                  style: TextStyle(
                    fontSize: 14,
                    color: gt.colors.textSecondary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _maxParticipants > 2
                      ? () => setState(() => _maxParticipants--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 20,
                ),
                Text(
                  '$_maxParticipants',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: gt.colors.primary,
                  ),
                ),
                IconButton(
                  onPressed: _maxParticipants < 20
                      ? () => setState(() => _maxParticipants++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: Spacing.space16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _create,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.mic),
                label: Text(l10n.voice_createButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gt.colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.button),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space8),
          ],
        ),
      ),
    );
  }
}
