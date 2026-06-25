import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/utils/dopamine_effects.dart';
import '../../profile/providers/settings_provider.dart';
import '../../../core/utils/helpers.dart';
import '../models/message_model.dart';
import '../../groups/widgets/poll_bubble.dart';
import 'package:dio/dio.dart';
import 'voice_message_bubble.dart';
import 'video_message_bubble.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/services/firebase_service.dart';
import '../../groups/models/poll_model.dart';
import '../../../shared/widgets/swipeable_message.dart';
import 'gaze_lock_overlay.dart';
import 'resonance_bubble_animation.dart';
import 'chronos_locked_bubble.dart';
import 'ambient_playback_widget.dart';
import '../../../core/utils/reaction_icons.dart';
import 'impact_text.dart';
import 'quantum_vault_bubble.dart';
import 'sonic_whisper_overlay.dart';
import '../../stickers/widgets/special_sticker_widget.dart';
import '../../../core/services/sentience_engine.dart';
import '../../../shared/widgets/black_hole_ripple.dart';

/// Message bubble widget — Phase 1 with reactions, reply, edit, delete,
/// forwarded tag, seen receipts, multi-select support
class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSenderName;
  final String? senderName;
  final String currentUid;
  final String chatId;
  final bool isGroup;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isMultiSelectMode;
  final bool isFirstInSequence;
  final bool isLastInSequence;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.senderName,
    this.currentUid = '',
    this.chatId = '',
    this.isGroup = false,
    this.onLongPress,
    this.onTap,
    this.isSelected = false,
    this.isMultiSelectMode = false,
    this.isFirstInSequence = true,
    this.isLastInSequence = true,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bubbleStyle = ref.watch(bubbleStyleProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final sentienceState = ref.watch(sentienceProvider(widget.chatId));

    // ── Deleted message placeholder ──
    if (widget.message.isDeleted) {
      return _buildDeletedBubble(ref, bubbleStyle);
    }

    // ── Chronos-locked message (contextual time-capsule) ──
    if (widget.message.isChronosLocked && !widget.isMe) {
      return ChronosLockedBubble(
        message: widget.message,
        isMe: widget.isMe,
        chatId: widget.chatId,
        isGroup: widget.isGroup,
      );
    }

    // Check if this is a new message (sent within last 5 seconds)
    final isNewMessage = DateTime.now().difference(widget.message.createdAt).inSeconds < 5;

    Widget bubble = ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onLongPressStart: (details) {
          AppHaptics.heavyTap();
          // Show dopamine feedback for long press
          if (widget.isMe) {
            DopamineEffects.showConfettiBurst(
              context,
              position: details.globalPosition,
              particleCount: 15,
              colors: [Colors.cyan, Colors.blue, Colors.purple],
              duration: const Duration(milliseconds: 600),
            );
          }
          widget.onLongPress?.call();
        },
        onTap: widget.onTap,
        child: Container(
          color:
              widget.isSelected
                  ? AppColors.aquaCore.withOpacity(0.08)
                  : Colors.transparent,
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.isMe ? 60 : 12,
              right: widget.isMe ? 12 : 60,
              bottom: 6,
              top: 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Multi-select checkbox
                if (widget.isMultiSelectMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            widget.isSelected
                                ? AppColors.aquaCore
                                : Colors.transparent,
                        border: Border.all(
                          color:
                              widget.isSelected
                                  ? AppColors.aquaCore
                                  : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child:
                          widget.isSelected
                              ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 13,
                              )
                              : null,
                    ),
                  ),
                ],

                // Bubble content
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        widget.isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                    children: [
                      // Sender name (group chats)
                      if (widget.showSenderName &&
                          widget.senderName != null &&
                          !widget.isMe)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 3),
                          child: Text(
                            widget.senderName!,
                            style: AppTextStyles.senderLabel,
                          ),
                        ),

                      // Forwarded tag
                      if (widget.message.isForwarded)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.forward_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                L10n.s(ref, 'forwarded'),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Bubble
                      Container(
                        padding: _getPadding(),
                        decoration:
                            widget.isMe
                                ? _getOutgoingDecoration(bubbleStyle, sentienceState)
                                : _getIncomingDecoration(bubbleStyle, sentienceState),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Reply preview inside bubble
                            if (widget.message.replyTo != null)
                              _buildReplyPreview(),

                            // Content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildContent(ref, fontSize),
                                const SizedBox(height: 4),
                                _buildTimestamp(ref),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Reaction badges below bubble
                      if (widget.message.reactions.isNotEmpty)
                        _buildReactionBadges(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap with Ripple Telepathy™ gaze lock overlay
    bubble = GazeLockOverlay(child: bubble);

    // Wrap with Emotional Resonance™ animation
    bubble = ResonanceBubbleAnimation(
      signature: widget.message.emotionalSignature,
      isMe: widget.isMe,
      child: bubble,
    );

    // Wrap with Ambient Sonic Footprints™ playback
    if (widget.message.ambientAudioUrl != null) {
      bubble = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          bubble,
          Padding(
            padding: EdgeInsets.only(
              left: widget.isMe ? 0 : 16,
              right: widget.isMe ? 16 : 0,
            ),
            child: AmbientPlaybackWidget(
              ambientAudioUrl: widget.message.ambientAudioUrl,
            ),
          ),
        ],
      );
    }

    // Return wrapped with dopamine effects for new messages
    if (isNewMessage) {
      return DopamineEffects.newMessagePop(
        isNew: true,
        child: bubble,
      );
    }

    return bubble;
  }

  BoxDecoration _getIncomingDecoration(String style, SentienceState sentience) {
    double radius = 20 * sentience.bubbleRoundness;
    if (style == 'sharp') radius = 4;
    if (style == 'minimal') radius = 12;

    return BoxDecoration(
      color: sentience.intensity > 0
          ? sentience.primaryGlow.withOpacity(0.15) 
          : AppColors.msgIn,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(widget.isFirstInSequence ? radius : 4),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(widget.isLastInSequence ? 4 : 4),
        bottomRight: Radius.circular(widget.isLastInSequence ? radius : 8),
      ),
      border: Border.all(
        color: sentience.intensity > 0
            ? sentience.primaryGlow.withOpacity(0.3)
            : AppColors.glassBorder.withOpacity(0.3),
        width: 0.5,
      ),
      boxShadow: sentience.intensity > 0
          ? [
              BoxShadow(
                color: sentience.primaryGlow.withOpacity(0.1 * sentience.intensity),
                blurRadius: 10 * sentience.intensity,
                spreadRadius: 2 * sentience.intensity,
              )
            ]
          : null,
    );
  }

  BoxDecoration _getOutgoingDecoration(String style, SentienceState sentience) {
    double radius = 20 * sentience.bubbleRoundness;
    if (style == 'sharp') radius = 4;
    if (style == 'minimal') radius = 12;

    return BoxDecoration(
      gradient: sentience.intensity > 0
          ? LinearGradient(
              colors: [sentience.primaryGlow, sentience.secondaryGlow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : AppColors.msgOutGradient,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(widget.isFirstInSequence ? radius : 4),
        bottomLeft: Radius.circular(widget.isLastInSequence ? radius : 8),
        bottomRight: Radius.circular(widget.isLastInSequence ? 4 : 4),
      ),
      border: Border.all(
        color: sentience.intensity > 0
            ? sentience.secondaryGlow.withOpacity(0.4)
            : AppColors.aquaCore.withOpacity(0.4),
        width: 0.5,
      ),
      boxShadow: sentience.intensity > 0
          ? [
              BoxShadow(
                color: sentience.secondaryGlow.withOpacity(0.2 * sentience.intensity),
                blurRadius: 12 * sentience.intensity,
                spreadRadius: 2 * sentience.intensity,
              )
            ]
          : [
              BoxShadow(
                color: AppColors.aquaCore.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  Widget _buildDeletedBubble(WidgetRef ref, String bubbleStyle) {
    final radius = bubbleStyle == 'sharp' ? 4.0 : 20.0;
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block,
                color: Colors.white.withOpacity(0.38),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                L10n.s(ref, 'messageDeleted'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    final reply = widget.message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.aquaCore.withOpacity(0.12),
        border: const Border(
          left: BorderSide(color: AppColors.aquaCore, width: 4),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.reply_rounded,
                color: AppColors.aquaCore,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                reply.senderName,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.aquaCore,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            reply.text.isEmpty ? '[${reply.type}]' : reply.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsetsGeometry _getPadding() {
    if (widget.message.isMediaMessage) {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildContent(WidgetRef ref, double fontSize) {
    // Quantum Vault™ — show scrambled message if quantum locked
    if (widget.message.isQuantumLocked && widget.message.isTextMessage) {
      return QuantumVaultBubble(
        actualText: widget.message.text ?? '',
        isMe: widget.isMe,
      );
    }

    switch (widget.message.type) {
      case 'image':
        return _buildImageContent(fontSize);
      case 'video':
        return _buildVideoContent();
      case 'circular_video':
        return _buildCircularVideoContent();
      case 'file':
        return _buildFileContent(ref);
      case 'voice':
        // Sonic Whispers™ — wrap voice messages with ambient-aware overlay
        final voiceWidget = _buildVoiceContent(ref);
        if (widget.message.mediaUrl != null) {
          return SonicWhisperOverlay(
            audioUrl: widget.message.mediaUrl!,
            isMe: widget.isMe,
            child: voiceWidget,
          );
        }
        return voiceWidget;
      case 'poll':
        return _buildPollContent();
      case 'gif':
        return _buildGifContent();
      case 'sticker':
        return _buildStickerContent();
      case 'text':
      case 'emoji':
      default:
        return _buildTextContent(fontSize);
    }
  }

  bool _isHighIntensity(String text) {
    if (text.isEmpty) return false;
    // Condition 1: Ends with multiple exclamation marks
    if (text.endsWith('!!')) return true;
    // Condition 2: ALL CAPS and at least 4 letters
    final letters = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (letters.length > 3 && letters == letters.toUpperCase()) return true;
    return false;
  }

  Widget _buildTextContent(double fontSize) {
    final isEmoji = widget.message.type == 'emoji';
    final text = widget.message.text ?? '';
    final actionItems = widget.message.actionItems;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isHighIntensity(text))
          ImpactText(text: text, fontSize: fontSize)
        else
          Text(
            text,
            style:
                isEmoji
                    ? TextStyle(fontSize: fontSize * 2.2)
                    : AppTextStyles.chatBubble.copyWith(
                      color: Colors.white,
                      fontSize: fontSize,
                      height: 1.4,
                    ),
          ),
        // Link preview if text contains a URL
        if (!isEmoji && _containsUrl(text)) ..._buildLinkPreview(text),
        // Action items chips
        if (actionItems != null && actionItems.isNotEmpty)
          _buildActionItemsChips(actionItems),
      ],
    );
  }

  bool _isSpecialSticker(String emoji) {
    return [
      '🌀', '🪼', '🪐', '⚡', '⚛️', '🔮', '💎', '✨', // NeoGlass
      '🌊', '🔷', '🔆', '❄️', '💧', '🌌', '💜', '🔵', // Ripple Signature
    ].contains(emoji);
  }

  Widget _buildStickerContent() {
    final sticker = widget.message.text ?? '';
    if (_isSpecialSticker(sticker)) {
      return SpecialStickerWidget(emoji: sticker);
    }
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(
        sticker,
        style: const TextStyle(fontSize: 64),
      ),
    );
  }

  Widget _buildActionItemsChips(List<String> actionItems) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: actionItems.map((task) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.aquaCore.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.aquaCore.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.task_alt,
                  size: 12,
                  color: AppColors.aquaCore,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    task,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static final _urlRegex = RegExp(
    r'(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  bool _containsUrl(String text) => _urlRegex.hasMatch(text);

  String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text)?.group(0);
    if (match == null) return null;
    // Ensure URL has a scheme
    if (!match.startsWith('http://') && !match.startsWith('https://')) {
      return 'https://$match';
    }
    return match;
  }

  List<Widget> _buildLinkPreview(String text) {
    final url = _extractUrl(text);
    if (url == null) return [];
    // Validate the link before rendering
    if (!AnyLinkPreview.isValidLink(url)) return [];
    return [
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AnyLinkPreview(
            link: url,
            displayDirection: UIDirection.uiDirectionVertical,
            showMultimedia: true,
            bodyMaxLines: 3,
            cache: const Duration(days: 7),
            titleStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            bodyStyle: const TextStyle(color: Colors.white60, fontSize: 11),
            backgroundColor: const Color(0xFF1E293B),
            borderRadius: 10,
            removeElevation: true,
            boxShadow: const [],
            onTap:
                () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
            errorBody: '',
            errorTitle: '',
            errorWidget: const SizedBox.shrink(),
          ),
        ),
      ),
    ];
  }

  Widget _buildPollContent() {
    final pollId = widget.message.mediaUrl ?? '';
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseService.firestore.collection('polls').doc(pollId).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox(
            width: 260,
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final poll = PollModel.fromMap(
          snap.data!.data() as Map<String, dynamic>,
        );
        return PollBubble(
          message: widget.message,
          poll: poll,
          currentUid: widget.currentUid,
          isMe: widget.isMe,
          onVote: (index) async {
            if (poll.hasVoted(widget.currentUid)) return;
            final newVotes = Map<String, List<String>>.from(poll.votes);
            newVotes[index] = [...(newVotes[index] ?? []), widget.currentUid];
            await snap.data!.reference.update({
              'votes': newVotes,
              'voterIds': FieldValue.arrayUnion([widget.currentUid]),
            });
          },
        );
      },
    );
  }

  Widget _buildVoiceContent(WidgetRef ref) {
    // Parse waveform data from message
    final rawWaveform = widget.message.toMap()['waveformData'];
    final waveformData =
        rawWaveform is List
            ? rawWaveform.map((e) => (e as num).toDouble()).toList()
            : <double>[];
    final duration = (widget.message.toMap()['duration'] as int?) ?? 0;

    return VoiceMessageBubble(
      audioUrl: widget.message.mediaUrl ?? '',
      durationSeconds: duration,
      waveformData: waveformData,
      isMyMessage: widget.isMe,
    );
  }

  Widget _buildGifContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        child:
            widget.message.mediaUrl != null
                ? CachedNetworkImage(
                  imageUrl: widget.message.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        width: 200,
                        height: 150,
                        color: AppColors.glassPanel,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppColors.aquaCore,
                            ),
                          ),
                        ),
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        width: 200,
                        height: 150,
                        color: AppColors.glassPanel,
                        child: const Icon(
                          Icons.gif_rounded,
                          color: AppColors.textMuted,
                          size: 40,
                        ),
                      ),
                )
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildImageContent(double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, maxHeight: 280),
            child:
                widget.message.mediaUrl != null
                    ? CachedNetworkImage(
                      imageUrl: widget.message.mediaUrl!,
                      fit: BoxFit.cover,
                      placeholder:
                          (_, __) => Container(
                            width: 200,
                            height: 150,
                            color: AppColors.glassPanel,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.aquaCore,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (_, __, ___) => Container(
                            width: 200,
                            height: 150,
                            color: AppColors.glassPanel,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: AppColors.textMuted,
                              size: 40,
                            ),
                          ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
        if (widget.message.text != null && widget.message.text!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              widget.message.text!,
              style: AppTextStyles.body.copyWith(
                color: Colors.white,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCircularVideoContent() {
    return VideoMessageBubble(
      videoUrl: widget.message.mediaUrl ?? '',
      isMe: widget.isMe,
    );
  }

  Widget _buildVideoContent() {
    // Use thumbnailUrl if available, otherwise show placeholder
    final thumbnailUrl = widget.message.toMap()['thumbnailUrl'] as String?;
    return GestureDetector(
      onTap: () {
        if (widget.message.mediaUrl != null) {
          launchUrl(
            Uri.parse(widget.message.mediaUrl!),
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 220,
          height: 160,
          color: AppColors.glassPanel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  fit: BoxFit.cover,
                  width: 220,
                  height: 160,
                )
              else if (widget.message.mediaUrl != null)
                Container(
                  width: 220,
                  height: 160,
                  color: Colors.black45,
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent(WidgetRef ref) {
    final fileName =
        widget.message.fileName ??
        (widget.message.text != null && widget.message.text!.isNotEmpty
            ? widget.message.text!
            : L10n.s(ref, 'document'));
    final ext = fileName.split('.').last.toLowerCase();

    return Builder(
      builder:
          (context) => GestureDetector(
            onTap: () => _downloadAndOpenFile(context, ref, fileName),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _getFileColor(ext),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFileIcon(ext),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ext.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.download_rounded,
                    color: AppColors.aquaCore,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _downloadAndOpenFile(
    BuildContext context,
    WidgetRef ref,
    String fileName,
  ) async {
    final url = widget.message.mediaUrl;
    if (url == null || url.isEmpty) return;

    // Show downloading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${L10n.s(ref, 'downloading')} $fileName...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 10),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      // Clean filename for filesystem
      final safeName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final savePath = '${dir.path}/$safeName';

      await Dio().download(url, savePath);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Open the file with system viewer
      final result = await OpenFilex.open(savePath);
      if (result.type != ResultType.done) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${L10n.s(ref, 'downloaded')} $fileName ✓  ${L10n.s(ref, 'noAppToOpenFile')}',
            ),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${L10n.s(ref, 'downloadFailed')}: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  static Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red.shade700;
      case 'doc':
      case 'docx':
        return Colors.blue.shade700;
      case 'xls':
      case 'xlsx':
        return Colors.green.shade700;
      case 'ppt':
      case 'pptx':
        return Colors.orange.shade700;
      case 'zip':
      case 'rar':
        return Colors.purple.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  static IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildDestructCountdown(Timestamp deleteAt) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) {
        final remaining =
            deleteAt.toDate().difference(DateTime.now()).inSeconds;
        return remaining < 0 ? 0 : remaining;
      }),
      builder: (_, snap) {
        final remaining =
            snap.data ?? deleteAt.toDate().difference(DateTime.now()).inSeconds;
        if (remaining <= 0) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_rounded, size: 10, color: Colors.red),
              const SizedBox(width: 3),
              Text(
                '${remaining}s',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimestamp(WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edited label
        if (widget.message.isEdited) ...[
          Text(
            L10n.s(ref, 'edited'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
        ],

        // Timestamp
        Text(
          Helpers.formatTime(widget.message.createdAt),
          style: AppTextStyles.caption.copyWith(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),

        // Seen receipts (for own messages)
        if (widget.isMe) ...[
          const SizedBox(width: 3),
          Icon(
            Icons.done_all_rounded,
            size: 14,
            color:
                widget.message.seenBy.any((uid) => uid != widget.currentUid)
                    ? AppColors.aquaCyan
                    : Colors.white.withOpacity(0.38),
          ),
        ],

        // Self-destruct countdown timer
        if (widget.message.deleteAt != null)
          _buildDestructCountdown(widget.message.deleteAt!),

        // Vanish Mode indicator
        if (widget.message.expiresAt != null)
          _buildVanishCountdown(widget.message.expiresAt!),
      ],
    );
  }

  Widget _buildVanishCountdown(Timestamp expiresAt) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      child: const Icon(
        Icons.auto_delete_outlined,
        size: 11,
        color: Colors.purpleAccent,
      ),
    );
  }

  Widget _buildReactionBadges() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children:
            widget.message.reactions.entries.map((entry) {
              final emoji = entry.key;
              final uids = entry.value;
              final iMReacted = uids.contains(widget.currentUid);

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      iMReacted
                          ? AppColors.aquaCore.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        iMReacted
                            ? AppColors.aquaCore
                            : Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getReactionWidget(emoji),
                    if (uids.length > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${uids.length}',
                        style: TextStyle(
                          color: iMReacted ? AppColors.aquaCore : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _getReactionWidget(String key) {
    return ReactionIcons.getIcon(key, size: 14);
  }
}
