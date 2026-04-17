import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glow_background.dart';
import '../../../core/widgets/pill_tag.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/voice_room_repository.dart';

/// 语音房详情页 —— 参与者网格 + 加入/离开/结束按钮。
class VoiceRoomDetailScreen extends ConsumerStatefulWidget {
  const VoiceRoomDetailScreen({super.key, required this.roomId});
  final String roomId;

  @override
  ConsumerState<VoiceRoomDetailScreen> createState() =>
      _VoiceRoomDetailScreenState();
}

class _VoiceRoomDetailScreenState
    extends ConsumerState<VoiceRoomDetailScreen> {
  bool _actionLoading = false;

  Future<void> _join() async {
    setState(() => _actionLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(voiceRoomRepositoryProvider).joinRoom(widget.roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voice_joinFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _leave() async {
    setState(() => _actionLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(voiceRoomRepositoryProvider).leaveRoom(widget.roomId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.voice_leaveFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _end() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.voice_endButton),
        content: Text(l10n.voice_endConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.voice_endButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(voiceRoomRepositoryProvider).endRoom(widget.roomId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final roomAsync = ref.watch(voiceRoomProvider(widget.roomId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: gt.colors.base,
      body: GlowBackground(
        child: roomAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(l10n.common_loadFailed,
                style: TextStyle(color: gt.colors.textSecondary)),
          ),
          data: (room) {
            if (room == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_off_outlined,
                        size: 64, color: gt.colors.textTertiary),
                    const SizedBox(height: Spacing.space12),
                    Text(l10n.voice_roomEnded,
                        style: TextStyle(color: gt.colors.textSecondary)),
                  ],
                ),
              );
            }

            final isHost = currentUid == room.hostId;
            final isParticipant = room.participants.contains(currentUid);

            return CustomScrollView(
              slivers: [
                // AppBar
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  title: Text(room.title),
                  pinned: true,
                  actions: [
                    if (room.isLive)
                      Padding(
                        padding:
                            const EdgeInsets.only(right: Spacing.space16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: gt.colors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: Spacing.space4),
                            Text(
                              l10n.voice_live,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: gt.colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // 房间信息卡
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.space16,
                      vertical: Spacing.space8,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(Spacing.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 话题
                          if (room.topic.isNotEmpty) ...[
                            Text(
                              room.topic,
                              style: TextStyle(
                                fontSize: 15,
                                color: gt.colors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: Spacing.space12),
                          ],
                          // 主持人 + 分类 + 人数
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    gt.colors.primary.withValues(alpha: 0.15),
                                backgroundImage: room.hostAvatar.isNotEmpty
                                    ? NetworkImage(room.hostAvatar)
                                    : null,
                                child: room.hostAvatar.isEmpty
                                    ? Icon(Icons.mic,
                                        size: 16, color: gt.colors.primary)
                                    : null,
                              ),
                              const SizedBox(width: Spacing.space8),
                              Text(
                                room.hostName.isNotEmpty
                                    ? room.hostName
                                    : l10n.voice_host,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: gt.colors.textPrimary,
                                ),
                              ),
                              if (room.category.isNotEmpty) ...[
                                const SizedBox(width: Spacing.space8),
                                PillTag(label: room.category),
                              ],
                              const Spacer(),
                              Icon(Icons.people_outline,
                                  size: 16, color: gt.colors.primary),
                              const SizedBox(width: Spacing.space4),
                              Text(
                                l10n.voice_participants(
                                    room.participantCount,
                                    room.maxParticipants),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: gt.colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 音频即将上线提示
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.space16,
                      vertical: Spacing.space4,
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(Spacing.space12),
                      child: Row(
                        children: [
                          Icon(Icons.headphones,
                              size: 20, color: gt.colors.info),
                          const SizedBox(width: Spacing.space8),
                          Expanded(
                            child: Text(
                              l10n.voice_audioComingSoon,
                              style: TextStyle(
                                fontSize: 13,
                                color: gt.colors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 参与者标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.space16,
                      Spacing.space16,
                      Spacing.space16,
                      Spacing.space8,
                    ),
                    child: Text(
                      l10n.voice_participants(room.participantCount, room.maxParticipants),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: gt.colors.textPrimary,
                      ),
                    ),
                  ),
                ),

                // 参与者网格
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.space16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: Spacing.space12,
                      crossAxisSpacing: Spacing.space12,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final uid = room.participants[index];
                        final isSpeaker = room.speakerIds.contains(uid);
                        final isHostUser = uid == room.hostId;
                        return _ParticipantTile(
                          uid: uid,
                          isSpeaker: isSpeaker,
                          isHost: isHostUser,
                          hostLabel: l10n.voice_host,
                          speakerLabel: l10n.voice_speaker,
                          listenerLabel: l10n.voice_listener,
                        );
                      },
                      childCount: room.participants.length,
                    ),
                  ),
                ),

                // 底部操作按钮
                if (room.isLive)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.space16),
                      child: _buildActionButton(
                        gt, l10n, isHost, isParticipant),
                    ),
                  ),

                // 底部留白
                const SliverToBoxAdapter(
                  child: SizedBox(height: Spacing.space32),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(
    GlassThemeData gt,
    AppLocalizations l10n,
    bool isHost,
    bool isParticipant,
  ) {
    if (isHost) {
      // 主持人：显示结束按钮
      return SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _actionLoading ? null : _end,
          icon: _actionLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.stop_circle_outlined),
          label: Text(
            l10n.voice_endButton,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: gt.colors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.button),
            ),
          ),
        ),
      );
    }

    if (isParticipant) {
      // 已加入：显示离开按钮
      return SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _actionLoading ? null : _leave,
          icon: _actionLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: gt.colors.textSecondary,
                  ),
                )
              : const Icon(Icons.exit_to_app),
          label: Text(
            l10n.voice_leaveButton,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: gt.colors.textSecondary,
            side: BorderSide(color: gt.colors.glassL2Border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.button),
            ),
          ),
        ),
      );
    }

    // 未加入：显示加入按钮
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _actionLoading ? null : _join,
        icon: _actionLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.mic),
        label: Text(
          l10n.voice_joinButton,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: gt.colors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.button),
          ),
        ),
      ),
    );
  }
}

/// 参与者头像瓦片。
class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.uid,
    required this.isSpeaker,
    required this.isHost,
    required this.hostLabel,
    required this.speakerLabel,
    required this.listenerLabel,
  });

  final String uid;
  final bool isSpeaker;
  final bool isHost;
  final String hostLabel;
  final String speakerLabel;
  final String listenerLabel;

  @override
  Widget build(BuildContext context) {
    final gt = GlassTheme.of(context);

    final roleLabel = isHost
        ? hostLabel
        : isSpeaker
            ? speakerLabel
            : listenerLabel;

    final ringColor = isHost
        ? gt.colors.accent
        : isSpeaker
            ? gt.colors.primary
            : Colors.transparent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: 2),
          ),
          child: CircleAvatar(
            radius: 26,
            backgroundColor: gt.colors.primary.withValues(alpha: 0.1),
            child: Icon(
              isHost
                  ? Icons.mic
                  : isSpeaker
                      ? Icons.record_voice_over
                      : Icons.headphones,
              size: 22,
              color: gt.colors.primary,
            ),
          ),
        ),
        const SizedBox(height: Spacing.space4),
        Text(
          roleLabel,
          style: TextStyle(
            fontSize: 10,
            color: isHost ? gt.colors.accent : gt.colors.textTertiary,
            fontWeight: isHost ? FontWeight.w600 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
