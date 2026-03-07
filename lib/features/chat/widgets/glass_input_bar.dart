import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../models/message_model.dart';
import 'voice_recorder_widget.dart';

/// Frosted glass input bar for the chat screen bottom
/// Phase 2: Added voice recording (hold mic) and GIF button
class GlassInputBar extends StatefulWidget {
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
  });

  @override
  State<GlassInputBar> createState() => _GlassInputBarState();
}

class _GlassInputBarState extends State<GlassInputBar> {
  bool _isRecording = false;
  double _dragOffset = 0;
  final GlobalKey<VoiceRecorderWidgetState> _voiceRecorderKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final content = Column(
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
        else
          _buildInputBar(),
      ],
    );

    if (kIsWeb) {
      return content;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: content,
      ),
    );
  }

  Widget _buildInputBar() {
    final hasText = widget.controller.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xCC060D1A),
        border: Border(
          top: BorderSide(color: Color(0x0FFFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          // Emoji button
          _IconBtn(
            icon: Icons.emoji_emotions_outlined,
            onTap: widget.onEmoji,
          ),

          // Attach button
          _IconBtn(
            icon: Icons.attach_file_rounded,
            onTap: widget.onAttach,
          ),

          // GIF button
          if (widget.onGif != null)
            _IconBtn(
              icon: Icons.gif_box_rounded,
              onTap: widget.onGif,
            ),

          const SizedBox(width: 4),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: const Color(0x0FFFFFFF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0x17FFFFFF),
                ),
              ),
              child: TextField(
                controller: widget.controller,
                style: AppTextStyles.body.copyWith(fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  widget.onChanged?.call(value);
                  setState(() {}); // Rebuild to show/hide mic vs send
                },
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Send button or Mic button
          if (hasText || widget.isSending)
            WaterRippleEffect(
              onTap: widget.isSending ? null : widget.onSend,
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
                child: widget.isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            )
          else
            // Mic button — hold to record
            GestureDetector(
              onLongPressStart: (_) {
                setState(() {
                  _isRecording = true;
                  _dragOffset = 0;
                });
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.aquaCore.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: AppColors.aquaCore,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.aquaCore.withOpacity(0.1),
        border: Border(
          left: BorderSide(
            color: AppColors.aquaCore,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
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
              child: Icon(Icons.close,
                  color: Colors.white.withOpacity(0.5), size: 18),
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

  const _IconBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: AppColors.textMuted, size: 22),
      ),
    );
  }
}
