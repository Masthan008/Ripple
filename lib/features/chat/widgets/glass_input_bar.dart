import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/water_ripple_painter.dart';

/// Frosted glass input bar for the chat screen bottom
/// Emoji button, attach button, text field, send button per PRD §6.3
class GlassInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onEmoji;
  final ValueChanged<String>? onChanged;
  final bool isSending;

  const GlassInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.onEmoji,
    this.onChanged,
    this.isSending = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
            onTap: onEmoji,
          ),

          // Attach button
          _IconBtn(
            icon: Icons.attach_file_rounded,
            onTap: onAttach,
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
                controller: controller,
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
                onChanged: onChanged,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Send button
          WaterRippleEffect(
            onTap: isSending ? null : onSend,
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
              child: isSending
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
          ),
        ],
      ),
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
