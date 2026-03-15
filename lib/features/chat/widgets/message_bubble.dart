import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/utils/helpers.dart';
import '../models/message_model.dart';
import 'voice_message_bubble.dart';

/// Message bubble widget — Phase 1 with reactions, reply, edit, delete,
/// forwarded tag, seen receipts, multi-select support
class MessageBubble extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    // ── Deleted message placeholder ──
    if (message.isDeleted) {
      return _buildDeletedBubble();
    }

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        color: isSelected
            ? AppColors.aquaCore.withOpacity(0.08)
            : Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(
            left: isMe ? 60 : 12,
            right: isMe ? 12 : 60,
            bottom: 6,
            top: 2,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Multi-select checkbox
              if (isMultiSelectMode) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.aquaCore
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.aquaCore
                            : Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 13)
                        : null,
                  ),
                ),
              ],

              // Bubble content
              Expanded(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    // Sender name (group chats)
                    if (showSenderName && senderName != null && !isMe)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 4, bottom: 3),
                        child: Text(senderName!,
                            style: AppTextStyles.senderLabel),
                      ),

                    // Forwarded tag
                    if (message.isForwarded)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 4, bottom: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forward_rounded,
                                color: Colors.white.withOpacity(0.4),
                                size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Forwarded',
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
                      decoration: isMe
                          ? GlassTheme.outgoingBubbleDecoration()
                          : GlassTheme.incomingBubbleDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply preview inside bubble
                          if (message.replyTo != null)
                            _buildReplyPreview(),

                          // Content
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.end,
                            children: [
                              _buildContent(),
                              const SizedBox(height: 4),
                              _buildTimestamp(),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Reaction badges below bubble
                    if (message.reactions.isNotEmpty)
                      _buildReactionBadges(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeletedBubble() {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        bottom: 6,
        top: 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block,
                  color: Colors.white.withOpacity(0.38), size: 16),
              const SizedBox(width: 8),
              Text(
                'This message was deleted',
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
    final reply = message.replyTo!;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.aquaCore.withOpacity(0.1),
        border: Border(
          left: BorderSide(color: AppColors.aquaCore, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.aquaCore,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            reply.text.isEmpty
                ? '[${reply.type}]'
                : reply.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
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
      case 'image':
        return _buildImageContent();
      case 'video':
        return _buildVideoContent();
      case 'file':
        return _buildFileContent();
      case 'voice':
        return _buildVoiceContent();
      case 'gif':
        return _buildGifContent();
      case 'text':
      case 'emoji':
      default:
        return _buildTextContent();
    }
  }

  Widget _buildTextContent() {
    final isEmoji = message.type == 'emoji';
    final text = message.text ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: isEmoji
              ? const TextStyle(fontSize: 32)
              : AppTextStyles.chatBubble.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
        ),
        // Link preview if text contains a URL
        if (!isEmoji && _containsUrl(text)) ..._buildLinkPreview(text),
      ],
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
            bodyStyle: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
            ),
            backgroundColor: const Color(0xFF1E293B),
            borderRadius: 10,
            removeElevation: true,
            boxShadow: const [],
            onTap: () => launchUrl(
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

  Widget _buildVoiceContent() {
    // Parse waveform data from message
    final rawWaveform = message.toMap()['waveformData'];
    final waveformData = rawWaveform is List
        ? rawWaveform.map((e) => (e as num).toDouble()).toList()
        : <double>[];
    final duration = (message.toMap()['duration'] as int?) ?? 0;

    return VoiceMessageBubble(
      audioUrl: message.mediaUrl ?? '',
      durationSeconds: duration,
      waveformData: waveformData,
      isMyMessage: isMe,
    );
  }

  Widget _buildGifContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 220,
          maxHeight: 220,
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
                  child: const Icon(Icons.gif_rounded,
                      color: AppColors.textMuted, size: 40),
                ),
              )
            : const SizedBox.shrink(),
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
                          valueColor: AlwaysStoppedAnimation(
                              AppColors.aquaCore),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 200,
                      height: 150,
                      color: AppColors.glassPanel,
                      child: const Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textMuted,
                          size: 40),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        if (message.text != null && message.text!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              message.text!,
              style: AppTextStyles.body
                  .copyWith(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoContent() {
    // Use thumbnailUrl if available, otherwise show placeholder
    final thumbnailUrl = message.toMap()['thumbnailUrl'] as String?;
    return GestureDetector(
      onTap: () {
        if (message.mediaUrl != null) {
          launchUrl(Uri.parse(message.mediaUrl!),
              mode: LaunchMode.externalApplication);
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
              else if (message.mediaUrl != null)
                Container(
                  width: 220,
                  height: 160,
                  color: Colors.black45,
                  child: const Icon(Icons.videocam_rounded,
                      color: Colors.white24, size: 48),
                ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent() {
    final fileName = message.fileName ??
        (message.text != null && message.text!.isNotEmpty
            ? message.text!
            : 'Document');
    final ext = fileName.split('.').last.toLowerCase();

    return Builder(
      builder: (context) => GestureDetector(
      onTap: () => _downloadAndOpenFile(context, fileName),
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
              child: Icon(_getFileIcon(ext),
                  color: Colors.white, size: 24),
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
                        color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.download_rounded,
                color: AppColors.aquaCore, size: 20),
          ],
        ),
      ),
    ));
  }

  Future<void> _downloadAndOpenFile(BuildContext context, String fileName) async {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return;

    // Show downloading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Downloading $fileName...',
                  overflow: TextOverflow.ellipsis),
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
            content: Text('Downloaded $fileName ✓  No app to open this file type.'),
            backgroundColor: const Color(0xFF1E293B),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  static Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf': return Colors.red.shade700;
      case 'doc': case 'docx': return Colors.blue.shade700;
      case 'xls': case 'xlsx': return Colors.green.shade700;
      case 'ppt': case 'pptx': return Colors.orange.shade700;
      case 'zip': case 'rar': return Colors.purple.shade700;
      default: return Colors.grey.shade700;
    }
  }

  static IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Widget _buildDestructCountdown(Timestamp deleteAt) {
    return StreamBuilder<int>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) {
          final remaining = deleteAt
              .toDate()
              .difference(DateTime.now())
              .inSeconds;
          return remaining < 0 ? 0 : remaining;
        },
      ),
      builder: (_, snap) {
        final remaining = snap.data ??
            deleteAt.toDate().difference(DateTime.now()).inSeconds;
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
              const Icon(Icons.timer_rounded,
                  size: 10, color: Colors.red),
              const SizedBox(width: 3),
              Text('${remaining}s',
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimestamp() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edited label
        if (message.isEdited) ...[
          Text(
            'Edited',
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
          Helpers.formatTime(message.createdAt),
          style: AppTextStyles.caption.copyWith(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),

        // Seen receipts (for own messages)
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            Icons.done_all_rounded,
            size: 14,
            color: message.seenBy
                    .any((uid) => uid != currentUid)
                ? AppColors.aquaCyan
                : Colors.white.withOpacity(0.38),
          ),
        ],

        // Self-destruct countdown timer
        if (message.deleteAt != null)
          _buildDestructCountdown(message.deleteAt!),
      ],
    );
  }

  Widget _buildReactionBadges() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions.entries.map((entry) {
          final emoji = entry.key;
          final uids = entry.value;
          final iMReacted = uids.contains(currentUid);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: iMReacted
                  ? AppColors.aquaCore.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iMReacted
                    ? AppColors.aquaCore
                    : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                if (uids.length > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${uids.length}',
                    style: TextStyle(
                      color: iMReacted
                          ? AppColors.aquaCore
                          : Colors.white,
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
}
