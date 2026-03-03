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
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../auth/models/user_model.dart';
import '../../calls/screens/agora_call_screen.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/glass_input_bar.dart';

/// 1-to-1 Chat Screen — PRD §6.3
/// Real-time messages, typing indicator, read receipts, glass input bar
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String partnerUid;
  final String partnerName;
  final String? partnerPhoto;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.partnerUid,
    required this.partnerName,
    this.partnerPhoto,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Note: Cannot use ref.read() here — ref is already disposed
    // Typing status will be cleared automatically by Firestore TTL
    // or when the user navigates back and reopens a chat
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
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: widget.chatId,
        text: text,
      );
      await chatService.clearTyping();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onTextChanged(String text) {
    final chatService = ref.read(chatServiceProvider);
    if (text.isNotEmpty) {
      chatService.setTypingTo(widget.partnerUid);
    } else {
      chatService.clearTyping();
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(chatPartnerProvider(widget.partnerUid));
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUser =
        ref.read(chatServiceProvider).myUid;

    // Auto-scroll on new messages
    messages.whenData((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // Subtle floating particles background
          const FloatingParticles(particleCount: 3),

          Column(
            children: [
              // Header
              _buildHeader(partner),

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
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: AppColors.aquaCore
                                    .withValues(alpha: 0.2),
                                size: 64),
                            const SizedBox(height: 12),
                            Text('Say hello! 👋',
                                style: AppTextStyles.bodySmall),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: msgs.length +
                          (partner.valueOrNull?.isTypingTo == currentUser
                              ? 1
                              : 0),
                      itemBuilder: (_, i) {
                        // Show typing indicator at the end
                        if (i == msgs.length) {
                          return const Padding(
                            padding: EdgeInsets.only(left: 12, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TypingIndicator(),
                            ),
                          );
                        }

                        final msg = msgs[i];
                        final isMe = msg.senderId == currentUser;

                        return MessageBubble(
                          message: msg,
                          isMe: isMe,
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
                onChanged: _onTextChanged,
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

  Widget _buildHeader(AsyncValue<UserModel?> partner) {
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
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Avatar
          AquaAvatar(
            imageUrl: widget.partnerPhoto,
            name: widget.partnerName,
            size: 36,
            showOnlineDot: true,
            isOnline: partner.valueOrNull?.isOnline ?? false,
          ),

          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partnerName,
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                partner.when(
                  data: (p) {
                    if (p == null) return const SizedBox.shrink();
                    if (p.isOnline) {
                      return Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.onlineGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Online',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.onlineGreen,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    }
                    if (p.lastSeen != null) {
                      return Text(
                        Helpers.formatLastSeen(p.lastSeen!),
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // Video call button
          GestureDetector(
            onTap: () => _startCall(isVideo: true),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: AppColors.lightWave, size: 18),
            ),
          ),

          const SizedBox(width: 8),

          // Audio call button
          GestureDetector(
            onTap: () => _startCall(isVideo: false),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(Icons.call_rounded,
                  color: AppColors.lightWave, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startCall({required bool isVideo}) async {
    final myUid = ref.read(chatServiceProvider).myUid;
    final callId = const Uuid().v4();

    try {
      // Create call document in Firestore
      await FirebaseService.firestore.collection('calls').doc(callId).set({
        'callerId': myUid,
        'calleeId': widget.partnerUid,
        'type': isVideo ? 'video' : 'audio',
        'isGroup': false,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AgoraCallScreen(
              callId: callId,
              channelName: widget.chatId,
              currentUserId: myUid,
              currentUserName: 'Me',
              otherUserName: widget.partnerName,
              isVideo: isVideo,
              isGroup: false,
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

      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: widget.chatId,
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
