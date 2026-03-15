import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_compressor.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/models/user_model.dart';
import '../../calls/screens/daily_call_screen.dart';
import '../../chat/models/message_model.dart';
import '../../chat/screens/chat_media_gallery_screen.dart';
import '../../chat/screens/video_player_screen.dart';
import '../../chat/services/message_actions_service.dart';
import '../../chat/widgets/forward_message_sheet.dart';
import '../../chat/widgets/gif_picker_sheet.dart';
import '../../chat/widgets/glass_input_bar.dart';
import '../../chat/widgets/message_bubble.dart';
import '../../chat/widgets/message_context_menu.dart';
import '../../chat/widgets/pinned_message_banner.dart';
import '../../../core/services/privacy_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/group_provider.dart';
import 'group_info_screen.dart';

/// Group Chat Screen — PRD §6.6
/// Phase 1: context menu, reactions, reply, edit, delete, forward, pin,
/// star, multi-select, seen receipts
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
  ConsumerState<GroupChatScreen> createState() =>
      _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _showEmojiPicker = false;

  // Phase 1 state
  ReplyData? _replyTo;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedMessageIds = {};

  // Phase 6 — Privacy state
  bool _incognitoKeyboard = false;
  int _selfDestructSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessageActionsService.markMessagesAsSeen(
        chatId: widget.groupId,
        currentUid: ref.read(groupServiceProvider).myUid,
        isGroup: true,
        selfDestructSeconds: _selfDestructSeconds,
      );
      _loadPrivacySettings();
    });
  }

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

    final replyData = _replyTo;
    setState(() => _replyTo = null);

    try {
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: text,
            replyTo: replyData,
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

  // ── Phase 1 helpers ────────────────────────────────────

  void _setReplyTo(MessageModel message, String senderName) {
    setState(() {
      _replyTo = ReplyData(
        messageId: message.id,
        senderName: message.senderId ==
                ref.read(groupServiceProvider).myUid
            ? 'You'
            : senderName,
        text: message.text ?? '',
        type: message.type,
        mediaUrl: message.mediaUrl,
      );
    });
  }

  // ── Phase 6 — Privacy helpers ──────────────────────────

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load self-destruct timer for this group
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups').doc(widget.groupId).get();
      final timer = groupDoc.data()?['selfDestructTimer'] as int? ?? 0;

      if (mounted) {
        setState(() {
          _incognitoKeyboard = prefs.getBool('incognito_keyboard') ?? false;
          _selfDestructSeconds = timer;
        });
      }
    } catch (e) {
      debugPrint('Privacy settings load error: $e');
    }
  }

  void _showSelfDestructPicker() {
    final options = [
      {'label': 'Off', 'value': 0},
      {'label': '5 seconds', 'value': 5},
      {'label': '10 seconds', 'value': 10},
      {'label': '30 seconds', 'value': 30},
      {'label': '1 minute', 'value': 60},
      {'label': '5 minutes', 'value': 300},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('💣 Self-Destruct Timer',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          ...options.map((o) => ListTile(
                leading: Icon(
                  o['value'] == 0
                      ? Icons.timer_off_rounded
                      : Icons.timer_rounded,
                  color: AppColors.aquaCore,
                ),
                title: Text(o['label'] as String,
                    style: const TextStyle(color: Colors.white)),
                trailing: _selfDestructSeconds == o['value'] as int
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.aquaCore)
                    : null,
                onTap: () async {
                  final seconds = o['value'] as int;
                  await PrivacyService.setSelfDestructTimer(
                    chatId: widget.groupId,
                    isGroup: true,
                    seconds: seconds,
                  );
                  setState(() => _selfDestructSeconds = seconds);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(seconds == 0
                          ? '💣 Timer disabled'
                          : '💣 Messages delete after ${o['label']}'),
                    ));
                  }
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatDestructTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m';
  }

  Future<void> _checkSelfDestruct(List<MessageModel> messages) async {
    final now = DateTime.now();
    for (final msg in messages) {
      if (msg.deleteAt != null && msg.deleteAt!.toDate().isBefore(now)) {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('messages')
            .doc(msg.id)
            .update({
          'isDeleted': true,
          'text': null,
          'mediaUrl': null,
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _showEditDialog(MessageModel message) {
    final editController =
        TextEditingController(text: message.text ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: AppColors.aquaCyan.withOpacity(0.2)),
        ),
        title: Text('Edit Message',
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: editController,
          style: AppTextStyles.body.copyWith(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Edit your message...',
            hintStyle: AppTextStyles.caption
                .copyWith(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.aquaCore),
            ),
          ),
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;
              try {
                await MessageActionsService.editMessage(
                  chatId: widget.groupId,
                  messageId: message.id,
                  newText: newText,
                  isGroup: true,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: AppColors.errorRed,
                    ),
                  );
                }
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showForwardSheet(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => ForwardMessageSheet(message: message),
    );
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _deleteSelectedForMe() async {
    for (final id in _selectedMessageIds) {
      await MessageActionsService.deleteForMe(
        chatId: widget.groupId,
        messageId: id,
        isGroup: true,
      );
    }
    _exitMultiSelect();
  }

  Future<void> _starSelected() async {
    for (final id in _selectedMessageIds) {
      await MessageActionsService.toggleStarMessage(
        chatId: widget.groupId,
        messageId: id,
        isGroup: true,
      );
    }
    _exitMultiSelect();
  }

  void _showContextMenu(
      MessageModel message, bool isMyMessage, String senderName) {
    showMessageContextMenu(
      context: context,
      message: message,
      isMyMessage: isMyMessage,
      chatId: widget.groupId,
      isGroup: true,
      currentUid: ref.read(groupServiceProvider).myUid,
      onReply: () => _setReplyTo(message, senderName),
      onEdit:
          isMyMessage ? () => _showEditDialog(message) : null,
      onDeleteForEveryone: () =>
          MessageActionsService.deleteForEveryone(
        chatId: widget.groupId,
        messageId: message.id,
        isGroup: true,
      ),
      onDeleteForMe: () => MessageActionsService.deleteForMe(
        chatId: widget.groupId,
        messageId: message.id,
        isGroup: true,
      ),
      onForward: () => _showForwardSheet(message),
      onPin: () => MessageActionsService.togglePinMessage(
        chatId: widget.groupId,
        messageId: message.id,
        pin: !message.isPinned,
        isGroup: true,
      ),
      onStar: () => MessageActionsService.toggleStarMessage(
        chatId: widget.groupId,
        messageId: message.id,
        isGroup: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages =
        ref.watch(groupMessagesProvider(widget.groupId));
    final members =
        ref.watch(groupMembersProvider(widget.groupId));
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

              // Pinned message banner
              PinnedMessageBanner(
                chatId: widget.groupId,
                isGroup: true,
                onTap: () {},
                onUnpin: () =>
                    MessageActionsService.togglePinMessage(
                  chatId: widget.groupId,
                  messageId: '',
                  pin: false,
                  isGroup: true,
                ),
              ),

              // Messages
              Expanded(
                child: messages.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          AppColors.aquaCore),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: AppTextStyles.caption),
                  ),
                  data: (msgs) {
                    _checkSelfDestruct(msgs);

                    final filtered = msgs
                        .where(
                            (m) => !m.deletedFor.contains(myUid))
                        .toList();

                    if (filtered.isEmpty) {
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final msg = filtered[i];
                        final isMe = msg.senderId == myUid;
                        final senderName =
                            memberNames[msg.senderId] ??
                                'Unknown';

                        return MessageBubble(
                          message: msg,
                          isMe: isMe,
                          showSenderName: !isMe,
                          senderName: senderName,
                          currentUid: myUid,
                          chatId: widget.groupId,
                          isGroup: true,
                          isSelected: _selectedMessageIds
                              .contains(msg.id),
                          isMultiSelectMode:
                              _isMultiSelectMode,
                          onLongPress: () {
                            if (_isMultiSelectMode) {
                              _toggleSelection(msg.id);
                            } else {
                              _showContextMenu(
                                  msg, isMe, senderName);
                            }
                          },
                          onTap: _isMultiSelectMode
                              ? () =>
                                  _toggleSelection(msg.id)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),

              // Multi-select bottom bar
              if (_isMultiSelectMode)
                _buildMultiSelectBar(),

              // Self-destruct banner
              if (!_isMultiSelectMode && _selfDestructSeconds > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: Colors.red.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Text('💣',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        'Messages delete after '
                        '${_formatDestructTime(_selfDestructSeconds)}',
                        style: TextStyle(
                            color: Colors.red.shade300, fontSize: 13),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          await PrivacyService.setSelfDestructTimer(
                            chatId: widget.groupId,
                            isGroup: true,
                            seconds: 0,
                          );
                          setState(() => _selfDestructSeconds = 0);
                        },
                        child: const Text('Turn Off',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              // Input bar
              if (!_isMultiSelectMode) ...[
                GlassInputBar(
                  controller: _messageController,
                  onSend: _sendMessage,
                  isSending: _isSending,
                  replyTo: _replyTo,
                  onClearReply: () =>
                      setState(() => _replyTo = null),
                  incognitoKeyboard: _incognitoKeyboard,
                  onEmoji: () {
                    setState(() => _showEmojiPicker =
                        !_showEmojiPicker);
                    if (_showEmojiPicker) {
                      FocusScope.of(context).unfocus();
                    }
                  },
                  onAttach: () =>
                      _showAttachmentSheet(context),
                  onGif: () => _showGifPicker(),
                  onVoiceRecorded: _sendVoiceMessage,
                ),

                // Emoji picker
                if (_showEmojiPicker)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _messageController.text +=
                            emoji.emoji;
                        _messageController.selection =
                            TextSelection.fromPosition(
                          TextPosition(
                              offset: _messageController
                                  .text.length),
                        );
                      },
                      config: const Config(
                        height: 250,
                        checkPlatformCompatibility: true,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xE6060D1A),
        border: Border(
          top: BorderSide(color: Color(0x0FFFFFFF), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _multiSelectAction(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: AppColors.errorRed,
            onTap: _deleteSelectedForMe,
          ),
          _multiSelectAction(
            icon: Icons.forward_to_inbox,
            label: 'Forward',
            color: Colors.white,
            onTap: () => _exitMultiSelect(),
          ),
          _multiSelectAction(
            icon: Icons.star_border,
            label: 'Star',
            color: Colors.amber,
            onTap: _starSelected,
          ),
          GestureDetector(
            onTap: _exitMultiSelect,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedMessageIds.length} selected',
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multiSelectAction({
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(fontSize: 10, color: color)),
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
            icon: const Icon(
                Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          StreamBuilder<
              DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .snapshots(),
            builder: (context, groupSnap) {
              final photoUrl = groupSnap.data
                  ?.data()?['photoUrl'] as String?;
              return AquaAvatar(
                imageUrl:
                    (photoUrl != null && photoUrl.isNotEmpty)
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
                  style: AppTextStyles.headingSmall
                      .copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                members.when(
                  data: (list) => Text(
                    '${list.length} members',
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 10),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) =>
                      const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // Video call button
          GestureDetector(
            onTap: () =>
                _startGroupCall(isVideo: true),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.5),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: AppColors.lightWave, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          // Audio call button
          GestureDetector(
            onTap: () =>
                _startGroupCall(isVideo: false),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.5),
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
                border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.5),
              ),
              child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.lightWave,
                  size: 18),
            ),
          ),
          const SizedBox(width: 4),
          // More menu (Media gallery)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.lightWave, size: 20),
            color: const Color(0xFF0C1E3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'media') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatMediaGalleryScreen(
                      chatId: widget.groupId,
                      isGroup: true,
                    ),
                  ),
                );
              } else if (value == 'self_destruct') {
                _showSelfDestructPicker();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'media',
                child: Row(
                  children: [
                    Icon(Icons.photo_library_rounded,
                        color: AppColors.aquaCore, size: 20),
                    SizedBox(width: 12),
                    Text('Media & Files',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'self_destruct',
                child: Row(
                  children: [
                    Text('💣', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 12),
                    Text('Self-Destruct Timer',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startGroupCall(
      {required bool isVideo}) async {
    final myUid = ref.read(groupServiceProvider).myUid;
    final callId = const Uuid().v4();
    final members = ref
            .read(groupMembersProvider(widget.groupId))
            .valueOrNull ??
        [];
    final memberIds =
        members.map((m) => m.uid).toList();

    try {
      await FirebaseService.firestore
          .collection('calls')
          .doc(callId)
          .set({
        'callerId': myUid,
        'callerName': 'Me',
        'channelName': widget.groupId,
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
            builder: (_) => DailyCallScreen(
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
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
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround,
              children: [
                _attachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF0EA5E9),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final pickedFiles = await ImagePicker()
                        .pickMultiImage(
                      imageQuality: 70,
                      maxWidth: 1920,
                      maxHeight: 1920,
                    );
                    if (pickedFiles.isEmpty) return;
                    final files = pickedFiles.take(10).toList();
                    setState(() => _isSending = true);
                    try {
                      for (final xfile in files) {
                        final compressed = await MediaCompressor
                            .compressImage(xfile.path);
                        await _sendMediaMessage(compressed, 'image');
                      }
                    } finally {
                      if (mounted) setState(() => _isSending = false);
                    }
                  },
                ),
                _attachOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF22D3EE),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await ImagePicker().pickImage(
                        source: ImageSource.camera,
                        imageQuality: 70);
                    if (file != null) {
                      final compressed = await MediaCompressor
                          .compressImage(file.path);
                      _sendMediaMessage(compressed, 'image');
                    }
                  },
                ),
                _attachOption(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: const Color(0xFF8B5CF6),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await ImagePicker().pickVideo(
                      source: ImageSource.gallery,
                      maxDuration: const Duration(seconds: 30),
                    );
                    if (file != null) {
                      _sendVideoMessage(File(file.path));
                    }
                  },
                ),
                _attachOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'File',
                  color: const Color(0xFFF59E0B),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await FilePicker.platform
                        .pickFiles(type: FileType.any);
                    if (result != null &&
                        result.files.single.path != null) {
                      _sendMediaMessage(
                        File(result.files.single.path!),
                        'file',
                        fileName:
                            result.files.single.name,
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
              style: AppTextStyles.caption
                  .copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(File file, String type,
      {String? fileName}) async {
    setState(() => _isSending = true);
    try {
      String? url;
      if (type == 'file') {
        // Files (PDFs, docs) → Supabase Storage
        final uniqueName =
            '${DateTime.now().millisecondsSinceEpoch}_${fileName ?? file.path.split('/').last}';
        url = await SupabaseService.uploadFile(file, uniqueName);
      } else if (type == 'video') {
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
            text: fileName ?? '[$type]',
            type: type,
            mediaUrl: url,
            fileName: fileName,
            replyTo: _replyTo,
          );
      setState(() => _replyTo = null);
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

  // ── Phase 2: GIF Picker ──────────────────────────────────
  void _showGifPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GifPickerSheet(
        onGifSelected: (gifUrl, previewUrl) async {
          setState(() => _isSending = true);
          try {
            await ref.read(groupServiceProvider).sendGroupMessage(
              groupId: widget.groupId,
              text: '',
              type: 'gif',
              mediaUrl: gifUrl,
            );
            _scrollToBottom();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send GIF: $e'),
                  backgroundColor: AppColors.errorRed,
                ),
              );
            }
          } finally {
            if (mounted) setState(() => _isSending = false);
          }
        },
      ),
    );
  }

  // ── Phase 2: Voice Message Upload ───────────────────────
  Future<void> _sendVoiceMessage(
    String filePath,
    Duration duration,
    List<double> waveformData,
  ) async {
    setState(() => _isSending = true);
    try {
      final file = File(filePath);
      final url = await CloudinaryService.uploadVideo(file);
      if (url == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Voice upload failed'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      final myUid = ref.read(groupServiceProvider).myUid;
      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'senderId': myUid,
        'type': 'voice',
        'mediaUrl': url,
        'duration': duration.inSeconds,
        'waveformData': waveformData,
        'text': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'isEdited': false,
        'isPinned': false,
        'isStarred': false,
        'isForwarded': false,
        'reactions': {},
        'seenBy': [myUid],
        'deletedFor': [],
        'starredBy': [],
      });

      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'lastMessage': {
          'text': '🎙️ Voice message',
          'senderId': myUid,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'voice',
        },
      });

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

  // ── Phase 2: Video with Thumbnail ───────────────────────
  Future<void> _sendVideoMessage(File videoFile) async {
    setState(() => _isSending = true);
    try {
      String? thumbUrl;
      try {
        final tempDir = await getTemporaryDirectory();
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 300,
          quality: 75,
        );
        if (thumbnailPath != null) {
          thumbUrl = await CloudinaryService.uploadImage(
              File(thumbnailPath));
        }
      } catch (_) {}

      final videoUrl = await CloudinaryService.uploadVideo(videoFile);
      if (videoUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video upload failed'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      final myUid = ref.read(groupServiceProvider).myUid;
      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
        'senderId': myUid,
        'type': 'video',
        'mediaUrl': videoUrl,
        'thumbnailUrl': thumbUrl,
        'text': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'isEdited': false,
        'isPinned': false,
        'isStarred': false,
        'isForwarded': false,
        'reactions': {},
        'seenBy': [myUid],
        'deletedFor': [],
        'starredBy': [],
      });

      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .update({
        'lastMessage': {
          'text': '🎬 Video',
          'senderId': myUid,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'video',
        },
      });

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
