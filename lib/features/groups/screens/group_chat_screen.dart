import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/models/user_model.dart';
import '../../calls/screens/agora_call_screen.dart';
import '../../chat/models/message_model.dart';
import '../../chat/widgets/message_bubble.dart';
import '../../chat/widgets/glass_input_bar.dart';
import '../providers/group_provider.dart';
import 'group_info_screen.dart';

/// Group Chat Screen — PRD §6.6
/// Real-time group messages with member names, admin badges
class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupPhoto;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupPhoto,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _showEmojiPicker = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: text,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(groupMessagesProvider(widget.groupId));
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final myUid = ref.read(groupServiceProvider).myUid;

    messages.whenData((_) => _scrollToBottom());

    // Build a lookup map for member names
    final memberNames = <String, String>{};
    members.whenData((list) {
      for (final m in list) {
        memberNames[m.uid] = m.name;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          const FloatingParticles(particleCount: 2),
          Column(
            children: [
              // Header
              _buildHeader(members),

              // Messages
              Expanded(
                child: messages.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.aquaCore),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: AppTextStyles.caption),
                  ),
                  data: (msgs) {
                    if (msgs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_outlined,
                                color: AppColors.aquaCore
                                    .withValues(alpha: 0.2),
                                size: 64),
                            const SizedBox(height: 12),
                            Text('No messages yet',
                                style: AppTextStyles.bodySmall),
                            const SizedBox(height: 4),
                            Text('Start the conversation!',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final msg = msgs[i];
                        final isMe = msg.senderId == myUid;

                        return MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showSenderName: !isMe,
                          senderName: memberNames[msg.senderId],
                        );
                      },
                    );
                  },
                ),
              ),

              // Input bar
              GlassInputBar(
                controller: _messageController,
                onSend: _sendMessage,
                isSending: _isSending,
                onEmoji: () {
                  setState(() => _showEmojiPicker = !_showEmojiPicker);
                  if (_showEmojiPicker) {
                    FocusScope.of(context).unfocus();
                  }
                },
                onAttach: () => _showAttachmentSheet(context),
              ),

              // Emoji picker
              if (_showEmojiPicker)
                SizedBox(
                  height: 250,
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _messageController.text += emoji.emoji;
                      _messageController.selection =
                          TextSelection.fromPosition(
                        TextPosition(
                            offset: _messageController.text.length),
                      );
                    },
                    config: const Config(
                      height: 250,
                      checkPlatformCompatibility: true,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<UserModel>> members) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xE6060D1A),
        border: Border(
          bottom: BorderSide(color: Color(0x0FFFFFFF), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .snapshots(),
            builder: (context, groupSnap) {
              final photoUrl =
                  groupSnap.data?.data()?['photoUrl'] as String?;
              return AquaAvatar(
                imageUrl: (photoUrl != null && photoUrl.isNotEmpty)
                    ? photoUrl
                    : widget.groupPhoto,
                name: widget.groupName,
                size: 36,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                members.when(
                  data: (list) => Text(
                    '${list.length} members',
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // Video call button
          GestureDetector(
            onTap: () => _startGroupCall(isVideo: true),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: AppColors.lightWave, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          // Audio call button
          GestureDetector(
            onTap: () => _startGroupCall(isVideo: false),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.call_rounded,
                  color: AppColors.lightWave, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          // Group info button
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(
                  groupId: widget.groupId,
                  groupName: widget.groupName,
                  groupPhoto: widget.groupPhoto,
                ),
              ),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: AppColors.lightWave, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startGroupCall({required bool isVideo}) async {
    final myUid = ref.read(groupServiceProvider).myUid;
    final callId = const Uuid().v4();
    final members = ref.read(groupMembersProvider(widget.groupId)).valueOrNull ?? [];
    final memberIds = members.map((m) => m.uid).toList();

    try {
      await FirebaseService.firestore.collection('calls').doc(callId).set({
        'callerId': myUid,
        'type': isVideo ? 'video' : 'audio',
        'isGroup': true,
        'groupId': widget.groupId,
        'groupName': widget.groupName,
        'memberIds': memberIds,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AgoraCallScreen(
              callId: callId,
              channelName: widget.groupId,
              currentUserId: myUid,
              currentUserName: 'Me',
              otherUserName: widget.groupName,
              isVideo: isVideo,
              isGroup: true,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  // ─── Attachment Bottom Sheet ───────────────────────────
  void _showAttachmentSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0C1E3A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF0EA5E9),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await ImagePicker()
                        .pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (file != null) _sendMediaMessage(File(file.path), MessageType.image);
                  },
                ),
                _attachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF22D3EE),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await ImagePicker()
                        .pickImage(source: ImageSource.camera, imageQuality: 70);
                    if (file != null) _sendMediaMessage(File(file.path), MessageType.image);
                  },
                ),
                _attachOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: const Color(0xFF8B5CF6),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await ImagePicker()
                        .pickVideo(source: ImageSource.gallery);
                    if (file != null) _sendMediaMessage(File(file.path), MessageType.video);
                  },
                ),
                _attachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  color: const Color(0xFFF59E0B),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await FilePicker.platform.pickFiles(type: FileType.any);
                    if (result != null && result.files.single.path != null) {
                      _sendMediaMessage(
                        File(result.files.single.path!),
                        MessageType.file,
                        fileName: result.files.single.name,
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(File file, MessageType type, {String? fileName}) async {
    setState(() => _isSending = true);
    try {
      String? url;
      if (type == MessageType.video) {
        url = await CloudinaryService.uploadVideo(file);
      } else {
        url = await CloudinaryService.uploadImage(file);
      }

      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: fileName ?? '[${type.name}]',
            type: type,
            mediaUrl: url,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
