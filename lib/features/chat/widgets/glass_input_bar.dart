import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassTheme, GlassCard;

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart'; // Add this
import '../../../shared/widgets/water_ripple_painter.dart';
import '../models/message_model.dart';
import 'voice_recorder_widget.dart';

import 'circular_video_recorder.dart';

/// Frosted glass input bar for the chat screen bottom
/// Phase 2: Added voice recording (hold mic) and GIF button
/// Phase 3: Added circular video recording (toggle mic)
class GlassInputBar extends ConsumerStatefulWidget {
  // Change to ConsumerStatefulWidget
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onEmoji;
  final VoidCallback? onGif;
  final ValueChanged<String>? onChanged;
  final bool isSending;
  final ReplyData? replyTo;
  final VoidCallback? onClearReply;
  final Function(String filePath, Duration duration, List<double> waveformData)?
  onVoiceRecorded;
  final Function(String filePath, Duration duration)? onVideoRecorded;
  final VoidCallback? onAiCompose;
  final VoidCallback? onToneFix;
  final VoidCallback? onSchedule;
  final VoidCallback? onSticker;
  final bool incognitoKeyboard;
  final bool isQuantumLocked;
  final VoidCallback? onQuantumToggle;

  const GlassInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onEmoji,
    this.onGif,
    this.onChanged,
    this.isSending = false,
    this.replyTo,
    this.onClearReply,
    this.onVoiceRecorded,
    this.onVideoRecorded,
    this.onAiCompose,
    this.onToneFix,
    this.onSchedule,
    this.onSticker,
    this.incognitoKeyboard = false,
    this.isQuantumLocked = false,
    this.onQuantumToggle,
  });

  @override
  ConsumerState<GlassInputBar> createState() => _GlassInputBarState();
}

class _GlassInputBarState extends ConsumerState<GlassInputBar> {
  bool _isRecording = false;
  bool _isRecordingVideo = false;
  bool _showVideoMode = false;
  double _dragOffset = 0;
  final GlobalKey<VoiceRecorderWidgetState> _voiceRecorderKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview bar
          if (widget.replyTo != null) _buildReplyPreview(),

          // Recording UI or normal input bar
          if (_isRecording)
            VoiceRecorderWidget(
              key: _voiceRecorderKey,
              onRecordingComplete: (path, duration, waveform) {
                setState(() => _isRecording = false);
                widget.onVoiceRecorded?.call(path, duration, waveform);
              },
              onCancelled: () {
                setState(() => _isRecording = false);
              },
            )
          else if (_isRecordingVideo)
            CircularVideoRecorder(
              onVideoRecorded: (path, duration) {
                setState(() => _isRecordingVideo = false);
                widget.onVideoRecorded?.call(path, duration);
              },
              onCancelled: () {
                setState(() => _isRecordingVideo = false);
              },
            )
          else
            _buildInputBar(),
        ],
      ),
    );

    return content;
  }

  Widget _buildInputBar() {
    final hasText = widget.controller.text.trim().isNotEmpty;

    return GlassContainer(
      useOwnLayer: true,
      settings: LiquidGlassSettings.ios27Dark,
      shape: const LiquidRoundedSuperellipse(borderRadius: 26),
      color: const Color(0xCC060D1A),
      padding: const EdgeInsets.only(
        left: 8,
        right: 8,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji button on the far left
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _IconBtn(
              icon: Icons.sentiment_satisfied_alt_rounded,
              size: 24,
              onTap: widget.onEmoji,
            ),
          ),

          const SizedBox(width: 4),

          // Expansive Text field taking up maximum width
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x17FFFFFF)),
              ),
              child: TextField(
                controller: widget.controller,
                style: AppTextStyles.body.copyWith(fontSize: 14.5),
                maxLines: 6,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                keyboardType:
                    widget.incognitoKeyboard
                        ? TextInputType.visiblePassword
                        : TextInputType.multiline,
                autocorrect: !widget.incognitoKeyboard,
                enableSuggestions: !widget.incognitoKeyboard,
                decoration: InputDecoration(
                  hintText: L10n.s(ref, 'typeMessage'),
                  hintStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  widget.onChanged?.call(value);
                  setState(() {});
                },
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Attach button on the right
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _IconBtn(
              icon: Icons.attach_file_rounded,
              size: 22,
              onTap: widget.onAttach,
            ),
          ),

          const SizedBox(width: 2),

          // Send button or Mic button
          if (hasText || widget.isSending)
            WaterRippleEffect(
              onTap:
                  widget.isSending
                      ? null
                      : () {
                        AppHaptics.success();
                        widget.onSend();
                      },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.aquaCore.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child:
                    widget.isSending
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                        : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
              ),
            )
          // Mic or Video button
          else
            GestureDetector(
              onTap: () {
                AppHaptics.mediumTap();
                setState(() {
                  _showVideoMode = !_showVideoMode;
                });
              },
              onLongPressStart: (_) {
                AppHaptics.heavyTap();
                setState(() {
                  if (_showVideoMode) {
                    _isRecordingVideo = true;
                  } else {
                    _isRecording = true;
                  }
                  _dragOffset = 0;
                });
              },
              onLongPressMoveUpdate: (details) {
                if (_isRecording) {
                  setState(() {
                    _dragOffset = details.localPosition.dx;
                  });
                  if (_dragOffset < -100) {
                    _voiceRecorderKey.currentState?.cancelRecording();
                  }
                }
              },
              onLongPressEnd: (_) {
                if (_isRecording) {
                  _voiceRecorderKey.currentState?.stopAndSend();
                }
              },
              child: WaterRippleEffect(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.aquaCore,
                  ),
                  child: Icon(
                    _showVideoMode ? Icons.videocam_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.aquaCore.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.aquaCore.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.aquaCore,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.replyTo!.senderName,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.aquaCore,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  widget.replyTo!.text.isEmpty
                      ? '[${widget.replyTo!.type}]'
                      : widget.replyTo!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onClearReply,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.5),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final double? size;

  const _IconBtn({required this.icon, this.onTap, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.lightTap();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Icon(
          icon,
          color: color ?? AppColors.textMuted,
          size: size ?? 20,
        ),
      ),
    );
  }
}
