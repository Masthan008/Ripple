import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../models/message_model.dart';
import 'video_player_screen.dart';

/// Media gallery screen — shows all media, files, and links in a chat
/// Accessible from chat header → 3-dot menu → 'Media & Files'
class ChatMediaGalleryScreen extends StatelessWidget {
  final String chatId;
  final bool isGroup;

  const ChatMediaGalleryScreen({
    super.key,
    required this.chatId,
    this.isGroup = false,
  });

  Stream<List<MessageModel>> _messagesStream() {
    final collection = isGroup
        ? FirebaseService.firestore
            .collection('groups')
            .doc(chatId)
            .collection('messages')
        : FirebaseService.chatsCollection
            .doc(chatId)
            .collection('messages');

    return collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MessageModel.fromFirestore(d)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.abyssBackground,
        appBar: AppBar(
          backgroundColor: AppColors.abyssBackground,
          title: Text('Media & Files', style: AppTextStyles.heading),
          bottom: TabBar(
            indicatorColor: AppColors.aquaCore,
            labelColor: AppColors.aquaCore,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'Media'),
              Tab(text: 'Files'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        body: StreamBuilder<List<MessageModel>>(
          stream: _messagesStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.aquaCore),
              );
            }

            final messages = snapshot.data!
                .where((m) => !m.isDeleted)
                .toList();

            return TabBarView(
              children: [
                _MediaTab(messages: messages),
                _FilesTab(messages: messages),
                _LinksTab(messages: messages),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Media tab — images, videos, GIFs in a grid
class _MediaTab extends StatelessWidget {
  final List<MessageModel> messages;
  const _MediaTab({required this.messages});

  @override
  Widget build(BuildContext context) {
    final mediaMessages = messages
        .where((m) =>
            m.type == 'image' || m.type == 'video' || m.type == 'gif')
        .toList();

    if (mediaMessages.isEmpty) {
      return _emptyState('No media shared yet');
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: mediaMessages.length,
      itemBuilder: (context, i) {
        final msg = mediaMessages[i];
        return GestureDetector(
          onTap: () {
            if (msg.type == 'video') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VideoPlayerScreen(videoUrl: msg.mediaUrl ?? ''),
                ),
              );
            } else {
              // Open fullscreen image viewer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FullScreenImage(
                    imageUrl: msg.mediaUrl ?? '',
                    heroTag: msg.id,
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: msg.mediaUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.white10),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white10,
                    child: const Icon(Icons.broken_image,
                        color: Colors.white24),
                  ),
                ),
              ),
              if (msg.type == 'video')
                Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.6),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              if (msg.type == 'gif')
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('GIF',
                        style: TextStyle(
                            color: Colors.white, fontSize: 9)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Files tab — documents with download
class _FilesTab extends StatelessWidget {
  final List<MessageModel> messages;
  const _FilesTab({required this.messages});

  @override
  Widget build(BuildContext context) {
    final fileMessages =
        messages.where((m) => m.type == 'file').toList();

    if (fileMessages.isEmpty) {
      return _emptyState('No files shared yet');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: fileMessages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final msg = fileMessages[i];
        final ext = (msg.fileName ?? '').split('.').last.toLowerCase();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
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
                      msg.fileName ?? 'File',
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
        );
      },
    );
  }
}

/// Links tab — messages containing URLs
class _LinksTab extends StatelessWidget {
  final List<MessageModel> messages;
  const _LinksTab({required this.messages});

  static final _urlRegex = RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final linkMessages = messages
        .where((m) =>
            m.text != null && _urlRegex.hasMatch(m.text!))
        .toList();

    if (linkMessages.isEmpty) {
      return _emptyState('No links shared yet');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: linkMessages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final msg = linkMessages[i];
        final url = _urlRegex.firstMatch(msg.text!)?.group(0) ?? '';
        return GestureDetector(
          onTap: () => launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.aquaCore,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.aquaCore,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _emptyState(String text) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              color: Colors.white.withValues(alpha: 0.2), size: 64),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );

Color _getFileColor(String ext) {
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

IconData _getFileIcon(String ext) {
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

/// Fullscreen image viewer with hero animation
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImage({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: AppColors.aquaCore),
            ),
          ),
        ),
      ),
    );
  }
}
