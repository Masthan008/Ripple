import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/utils/helpers.dart';
import '../models/message_model.dart';

/// Message bubble widget — incoming (glass) and outgoing (cyan gradient)
/// Per PRD §4.3 Component Specs — Message Bubbles
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showSenderName;
  final String? senderName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSenderName = false,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        bottom: 6,
        top: 2,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name (group chats)
          if (showSenderName && senderName != null && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(senderName!, style: AppTextStyles.senderLabel),
            ),

          // Bubble
          Container(
            padding: _getPadding(),
            decoration: isMe
                ? GlassTheme.outgoingBubbleDecoration()
                : GlassTheme.incomingBubbleDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildContent(),
                const SizedBox(height: 4),
                _buildTimestamp(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsetsGeometry _getPadding() {
    if (message.isMediaMessage) {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  Widget _buildContent() {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent();
      case MessageType.video:
        return _buildVideoContent();
      case MessageType.file:
        return _buildFileContent();
      case MessageType.text:
      case MessageType.emoji:
        return _buildTextContent();
    }
  }

  Widget _buildTextContent() {
    final isEmoji = message.type == MessageType.emoji;
    return Text(
      message.text,
      style: isEmoji
          ? const TextStyle(fontSize: 32)
          : AppTextStyles.body.copyWith(
              color: Colors.white,
              height: 1.4,
            ),
    );
  }

  Widget _buildImageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 220,
              maxHeight: 280,
            ),
            child: message.mediaUrl != null
                ? CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 200,
                      height: 150,
                      color: AppColors.glassPanel,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.aquaCore),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 200,
                      height: 150,
                      color: AppColors.glassPanel,
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppColors.textMuted, size: 40),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (message.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              message.text,
              style: AppTextStyles.body.copyWith(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        height: 150,
        color: AppColors.glassPanel,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (message.mediaUrl != null)
              CachedNetworkImage(
                imageUrl: message.mediaUrl!,
                fit: BoxFit.cover,
                width: 200,
                height: 150,
              ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.abyssBackground.withValues(alpha: 0.6),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.aquaCore.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.description_rounded,
              color: AppColors.aquaCore, size: 22),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text.isNotEmpty ? message.text : 'Document',
                style: AppTextStyles.label.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('Tap to open',
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.download_rounded,
            color: AppColors.aquaCore.withValues(alpha: 0.7), size: 20),
      ],
    );
  }

  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Helpers.formatTime(message.timestamp),
          style: AppTextStyles.caption.copyWith(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            message.isRead
                ? Icons.done_all_rounded
                : Icons.done_rounded,
            size: 14,
            color: message.isRead
                ? AppColors.aquaCyan
                : Colors.white.withValues(alpha: 0.5),
          ),
        ],
      ],
    );
  }
}
