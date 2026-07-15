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
// Add this
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/media_compressor.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/ai_service.dart';
import '../../auth/models/user_model.dart';
import '../../calls/screens/daily_call_screen.dart';
import '../../chat/models/message_model.dart';
import '../../chat/screens/chat_media_gallery_screen.dart';
import '../../chat/services/message_actions_service.dart';
import '../../chat/widgets/forward_message_sheet.dart';
import '../../chat/widgets/gif_picker_sheet.dart';
import '../../chat/widgets/glass_input_bar.dart';
import '../../chat/widgets/message_bubble.dart';
import '../../chat/widgets/message_context_menu.dart';
import '../../chat/widgets/pinned_message_banner.dart';
import '../../../core/services/privacy_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../chat/providers/chat_provider.dart';
import '../providers/group_provider.dart';
import 'group_info_screen.dart';
import '../models/poll_model.dart';
import '../../../shared/widgets/aurora_background.dart';
import '../widgets/create_poll_sheet.dart';
import '../widgets/poll_bubble.dart';
import '../providers/semantic_currents_provider.dart';
import '../widgets/semantic_currents_bar.dart';
import '../../../core/services/notification_service.dart';
import '../../chat/widgets/gaze_lock_overlay.dart';
import '../../chat/widgets/location_selector_sheet.dart';
import '../../chat/widgets/contact_selector_sheet.dart';
import '../widgets/spatial_canvas_view.dart';
import '../../../core/services/sentience_engine.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../stickers/widgets/sticker_picker_sheet.dart';

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
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
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

  // In-Chat Search state
  bool _isSearching = false;
  final _searchController = TextEditingController();

  // Mentions state
  bool _showMentionsOverlay = false;
  String _mentionFilter = '';

  // AI Features state
  bool _isSummarizing = false;
  String? _summary;

  // Spatial Threads™ state
  bool _isSpatialMode = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageTextChanged);
    // Track active chat for foreground notification suppression
    NotificationService.currentActiveChatId = widget.groupId;
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
    _messageController.removeListener(_onMessageTextChanged);
    // Clear active chat tracking
    NotificationService.currentActiveChatId = null;
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
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
      await ref
          .read(groupServiceProvider)
          .sendGroupMessage(
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
            backgroundColor: AppColors.errorRed,
          ),
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
        senderName:
            message.senderId == ref.read(groupServiceProvider).myUid
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
      final groupDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .get();
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
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '💣 Self-Destruct Timer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...options.map(
                (o) => ListTile(
                  leading: Icon(
                    o['value'] == 0
                        ? Icons.timer_off_rounded
                        : Icons.timer_rounded,
                    color: AppColors.aquaCore,
                  ),
                  title: Text(
                    o['label'] as String,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing:
                      _selfDestructSeconds == o['value'] as int
                          ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.aquaCore,
                          )
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            seconds == 0
                                ? '💣 Timer disabled'
                                : '💣 Messages delete after ${o['label']}',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
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
    final editController = TextEditingController(text: message.text ?? '');
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.aquaCyan.withOpacity(0.2)),
            ),
            title: Text(
              'Edit Message',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            content: TextField(
              controller: editController,
              style: AppTextStyles.body.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Edit your message...',
                hintStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.aquaCore),
                ),
              ),
              autofocus: true,
              maxLines: null,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMuted),
                ),
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

  Future<void> _catchUpSummary() async {
    setState(() => _isSummarizing = true);
    try {
      final messages = ref.read(groupMessagesProvider(widget.groupId)).valueOrNull ?? [];
      final chatMessages = messages.take(50).map((m) => {
        'sender': m.senderId,
        'text': m.text ?? '',
      }).toList();

      final summary = await AiService.summariseChat(
        messages: chatMessages,
        chatName: widget.groupName,
      );

      setState(() => _summary = summary);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppColors.aquaCyan.withOpacity(0.2)),
            ),
            title: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                const Text('Catch Up Summary', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(
                  summary,
                  style: const TextStyle(color: Colors.white70, height: 1.5),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppColors.aquaCore)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate summary: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  void _showForwardSheet(MessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    MessageModel message,
    bool isMyMessage,
    String senderName,
  ) {
    showMessageContextMenu(
      context: context,
      message: message,
      isMyMessage: isMyMessage,
      chatId: widget.groupId,
      isGroup: true,
      currentUid: ref.read(groupServiceProvider).myUid,
      onReply: () => _setReplyTo(message, senderName),
      onEdit: isMyMessage ? () => _showEditDialog(message) : null,
      onDeleteForEveryone:
          () => MessageActionsService.deleteForEveryone(
            chatId: widget.groupId,
            messageId: message.id,
            isGroup: true,
          ),
      onDeleteForMe:
          () => MessageActionsService.deleteForMe(
            chatId: widget.groupId,
            messageId: message.id,
            isGroup: true,
          ),
      onForward: () => _showForwardSheet(message),
      onPin:
          () => MessageActionsService.togglePinMessage(
            chatId: widget.groupId,
            messageId: message.id,
            pin: !message.isPinned,
            isGroup: true,
          ),
      onStar:
          () => MessageActionsService.toggleStarMessage(
            chatId: widget.groupId,
            messageId: message.id,
            isGroup: true,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(groupMessagesProvider(widget.groupId));
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final myUid = ref.read(groupServiceProvider).myUid;

    messages.whenData((_) => _scrollToBottom());

    // Build a lookup map for member names and photos
    final memberNames = <String, String>{};
    final memberPhotos = <String, String>{};
    members.whenData((list) {
      for (final m in list) {
        memberNames[m.uid] = m.name;
        if (m.photoUrl.isNotEmpty) {
          memberPhotos[m.uid] = m.photoUrl;
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: AuroraBackground(
        child: Stack(
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
                onUnpin:
                    () => MessageActionsService.togglePinMessage(
                      chatId: widget.groupId,
                      messageId: '',
                      pin: false,
                      isGroup: true,
                    ),
              ),

              // Semantic Currents™ — Topic filter bar
              messages.when(
                data: (msgs) => SemanticCurrentsBar(messages: msgs),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Messages
              Expanded(
                child: messages.when(
                  loading:
                      () => const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.aquaCore,
                          ),
                        ),
                      ),
                  error:
                      (e, _) => Center(
                        child: Text('Error: $e', style: AppTextStyles.caption),
                      ),
                  data: (msgs) {
                    _checkSelfDestruct(msgs);

                    var filtered =
                        msgs
                            .where((m) => !m.deletedFor.contains(myUid))
                            .toList();

                    // Local message search filter
                    if (_isSearching && _searchController.text.isNotEmpty) {
                      final query = _searchController.text.toLowerCase();
                      filtered = filtered.where((m) {
                        return m.text != null && m.text!.toLowerCase().contains(query);
                      }).toList();
                    }

                    // Apply Semantic Currents™ topic filter
                    final topicFiltered = ref.watch(
                      filteredMessagesByTopicProvider(filtered),
                    );

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              color: AppColors.aquaCore.withValues(alpha: 0.2),
                              size: 64,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet',
                              style: AppTextStyles.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start the conversation!',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      );
                    }

                    if (_isSpatialMode) {
                      return SpatialCanvasView(
                        groupId: widget.groupId,
                        messages: topicFiltered,
                        currentUid: myUid,
                        memberNames: memberNames,
                        memberPhotos: memberPhotos,
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: topicFiltered.length,
                      itemBuilder: (_, i) {
                        final isFirstInSequence = i == 0 || 
                            (i > 0 && i < topicFiltered.length && topicFiltered[i].senderId != topicFiltered[i - 1].senderId);
                        final isLastInSequence = i == topicFiltered.length - 1 || 
                            (i < topicFiltered.length - 1 && topicFiltered[i].senderId != topicFiltered[i + 1].senderId);

                        final msg = topicFiltered[i];
                        final isMe = msg.senderId == myUid;
                        final senderName =
                            memberNames[msg.senderId] ?? 'Unknown';

                        Widget bubbleChild;

                        if (msg.type == 'poll' &&
                            msg.toMap()['pollData'] != null) {
                          final pollData =
                              msg.toMap()['pollData'] as Map<String, dynamic>;
                          final pollModel = PollModel.fromMap(pollData);

                          bubbleChild = PollBubble(
                            message: msg,
                            poll: pollModel,
                            currentUid: myUid,
                            isMe: isMe,
                            onVote: (optionIndex) async {
                              if (pollModel.hasVoted(myUid)) return;

                              final newVotes = Map<String, List<String>>.from(
                                pollModel.votes,
                              );
                              newVotes[optionIndex] = [
                                ...(newVotes[optionIndex] ?? []),
                                myUid,
                              ];

                              await FirebaseService.firestore
                                  .collection('groups')
                                  .doc(widget.groupId)
                                  .collection('messages')
                                  .doc(msg.id)
                                  .update({'pollData.votes': newVotes});
                            },
                          );
                        } else {
                          bubbleChild =
                              MessageBubble(
                                    message: msg,
                                    isMe: isMe,
                                    showSenderName: !isMe,
                                    senderName: senderName,
                                    currentUid: myUid,
                                    chatId: widget.groupId,
                                    isGroup: true,
                                    isSelected: _selectedMessageIds.contains(
                                      msg.id,
                                    ),
                                    isMultiSelectMode: _isMultiSelectMode,
                                    isFirstInSequence: isFirstInSequence,
                                    isLastInSequence: isLastInSequence,
                                    onLongPress: () {
                                      if (_isMultiSelectMode) {
                                        _toggleSelection(msg.id);
                                      } else {
                                        _showContextMenu(msg, isMe, senderName);
                                      }
                                    },
                                    onTap:
                                        _isMultiSelectMode
                                            ? () => _toggleSelection(msg.id)
                                            : null,
                                  )
                                  as Widget;
                        }

                        // Also wrap PollBubble in a GestureDetector for multi-select if needed.
                        if (msg.type == 'poll') {
                          return GestureDetector(
                            onLongPress: () {
                              if (_isMultiSelectMode) {
                                _toggleSelection(msg.id);
                              } else {
                                _showContextMenu(msg, isMe, senderName);
                              }
                            },
                            onTap:
                                _isMultiSelectMode
                                    ? () => _toggleSelection(msg.id)
                                    : null,
                            child: Container(
                              color:
                                  _selectedMessageIds.contains(msg.id)
                                      ? AppColors.aquaCore.withValues(
                                        alpha: 0.1,
                                      )
                                      : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 12,
                              ),
                              alignment:
                                  isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                              child: bubbleChild,
                            ),
                          );
                        }

                        return bubbleChild;
                      },
                    );
                  },
                ),
              ),

              // Multi-select bottom bar
              if (_isMultiSelectMode) _buildMultiSelectBar(),

              // Self-destruct banner
              if (!_isMultiSelectMode && _selfDestructSeconds > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.red.withOpacity(0.1),
                  child: Row(
                    children: [
                      const Text('💣', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        'Messages delete after '
                        '${_formatDestructTime(_selfDestructSeconds)}',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 13,
                        ),
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
                        child: const Text(
                          'Turn Off',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Mentions overlay
              if (!_isMultiSelectMode && _showMentionsOverlay)
                members.maybeWhen(
                  data: (list) => _buildMentionsOverlay(list),
                  orElse: () => const SizedBox.shrink(),
                ),

              // Input bar
              if (!_isMultiSelectMode) ...[
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseService.firestore
                      .collection('groups')
                      .doc(widget.groupId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final gData = snapshot.data?.data();
                    final onlyAdminsCanMessage =
                        gData?['onlyAdminsCanMessage'] as bool? ?? false;
                    final admins = List<String>.from(gData?['admins'] ?? []);
                    final isUserAdmin = admins.contains(myUid);

                    if (onlyAdminsCanMessage && !isUserAdmin) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.glassPanel,
                          border: Border(
                            top: BorderSide(color: AppColors.glassBorder),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Only admins can send messages in this group',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    }

                    return GlassInputBar(
                      controller: _messageController,
                      onSend: _sendMessage,
                      isSending: _isSending,
                      replyTo: _replyTo,
                      onClearReply: () => setState(() => _replyTo = null),
                      incognitoKeyboard: _incognitoKeyboard,
                      onEmoji: () {
                        setState(() => _showEmojiPicker = !_showEmojiPicker);
                        if (_showEmojiPicker) {
                          FocusScope.of(context).unfocus();
                        }
                      },
                      onAttach: () => _showAttachmentSheet(context),
                      onGif: () => _showGifPicker(),
                      onVoiceRecorded: _sendVoiceMessage,
                      onVideoRecorded: _sendCircularVideoMessage,
                      onSticker: () => _showStickerPicker(context),
                    );
                  },
                ),

                // Emoji picker
                if (_showEmojiPicker)
                  SizedBox(
                    height: 250,
                    child: EmojiPicker(
                      onEmojiSelected: (category, emoji) {
                        _messageController.text += emoji.emoji;
                        _messageController
                            .selection = TextSelection.fromPosition(
                          TextPosition(offset: _messageController.text.length),
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

          // Ripple Telepathy™ — Full-screen lockdown when shoulder surfer detected
          const ShoulderSurferLockdown(),
        ],
      ),
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
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF), width: 1)),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_selectedMessageIds.length} selected',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontSize: 12,
                ),
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
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<UserModel>> members) {
    if (_isSearching) {
      return Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 16,
          bottom: 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xE6060D1A),
          border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF), width: 1)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 15),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {});
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                  });
                },
              ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xE6060D1A),
        border: Border(bottom: BorderSide(color: Color(0x0FFFFFFF), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId)
                    .snapshots(),
            builder: (context, groupSnap) {
              final photoUrl = groupSnap.data?.data()?['photoUrl'] as String?;
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
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                members.when(
                  data:
                      (list) => Text(
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
              child: const Icon(
                Icons.videocam_rounded,
                color: AppColors.lightWave,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Spatial Threads toggle
          GestureDetector(
            onTap: () {
              setState(() => _isSpatialMode = !_isSpatialMode);
              AppHaptics.lightTap();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isSpatialMode ? const Color(0xFF6366F1).withOpacity(0.2) : AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSpatialMode ? const Color(0xFF6366F1) : AppColors.glassBorder, 
                  width: _isSpatialMode ? 1.5 : 0.5,
                ),
              ),
              child: Icon(
                _isSpatialMode ? Icons.grain_rounded : Icons.hub_outlined,
                color: _isSpatialMode ? const Color(0xFF6366F1) : AppColors.lightWave,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Catch Up button
          GestureDetector(
            onTap: _isSummarizing ? null : _catchUpSummary,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: _isSummarizing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: 18,
                    ),
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
              child: const Icon(
                Icons.call_rounded,
                color: AppColors.lightWave,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Group info button
          GestureDetector(
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => GroupInfoScreen(
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
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.lightWave,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // More menu (Media gallery)
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.lightWave,
              size: 20,
            ),
            color: const Color(0xFF0C1E3A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'media') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ChatMediaGalleryScreen(
                          chatId: widget.groupId,
                          isGroup: true,
                        ),
                  ),
                );
              } else if (value == 'self_destruct') {
                _showSelfDestructPicker();
              } else if (value == 'search') {
                setState(() {
                  _isSearching = true;
                });
              }
            },
            itemBuilder:
                (_) => [
                  const PopupMenuItem(
                    value: 'media',
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_library_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Media & Files',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'self_destruct',
                    child: Row(
                      children: [
                        Text('💣', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 12),
                        Text(
                          'Self-Destruct Timer',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'search',
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Search Messages',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  Future<void> _startGroupCall({required bool isVideo}) async {
    final myUid = ref.read(groupServiceProvider).myUid;
    final callId = const Uuid().v4();
    final members =
        ref.read(groupMembersProvider(widget.groupId)).valueOrNull ?? [];
    final memberIds = members.map((m) => m.uid).toList();

    try {
      await FirebaseService.firestore.collection('calls').doc(callId).set({
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

      // Post a system message so group members can see & join the call
      final callerName =
          members.where((m) => m.uid == myUid).map((m) => m.name).firstOrNull ??
          'Someone';
      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
            'senderId': myUid,
            'type': 'call_invite',
            'text': '$callerName started a ${isVideo ? 'video' : 'voice'} call',
            'callId': callId,
            'callType': isVideo ? 'video' : 'audio',
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

      // Update group's lastMessage
      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .update({
            'lastMessage': {
              'text': '${isVideo ? '📹' : '📞'} $callerName started a call',
              'senderId': myUid,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'call_invite',
            },
          });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => DailyCallScreen(
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
      builder:
          (_) => Padding(
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
                        final pickedFiles = await ImagePicker().pickMultiImage(
                          imageQuality: 70,
                          maxWidth: 1920,
                          maxHeight: 1920,
                        );
                        if (pickedFiles.isEmpty) return;
                        final files = pickedFiles.take(10).toList();
                        if (files.length == 1) {
                          final compressed =
                              await MediaCompressor.compressImage(files.first.path);
                          _showMediaSendPreviewSheet(compressed, 'image');
                        } else {
                          setState(() => _isSending = true);
                          try {
                            for (final xfile in files) {
                              final compressed =
                                  await MediaCompressor.compressImage(xfile.path);
                              await _sendMediaMessage(compressed, 'image');
                            }
                          } finally {
                            if (mounted) setState(() => _isSending = false);
                          }
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
                          imageQuality: 70,
                        );
                        if (file != null) {
                          final compressed =
                              await MediaCompressor.compressImage(file.path);
                          _showMediaSendPreviewSheet(compressed, 'image');
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
                          _showMediaSendPreviewSheet(File(file.path), 'video');
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _attachOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'File',
                      color: const Color(0xFFF59E0B),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                        );
                        if (result != null &&
                            result.files.single.path != null) {
                          _sendMediaMessage(
                            File(result.files.single.path!),
                            'file',
                            fileName: result.files.single.name,
                          );
                        }
                      },
                    ),
                    _attachOption(
                      icon: Icons.poll_rounded,
                      label: 'Poll',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreatePollSheet();
                      },
                    ),
                    _attachOption(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => LocationSelectorSheet(
                            onLocationSelected: (lat, lng, {isLive = false}) {
                              _sendLocationMessage(lat, lng, isLive: isLive);
                            },
                          ),
                        );
                      },
                    ),
                    _attachOption(
                      icon: Icons.person_rounded,
                      label: 'Contact',
                      color: const Color(0xFFF59E0B),
                      onTap: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => ContactSelectorSheet(
                            onContactSelected: (name, uid) {
                              _sendContactCard(name, uid);
                            },
                          ),
                        );
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
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(
    File file,
    String type, {
    String? fileName,
    bool isViewOnce = false,
  }) async {
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

      await ref
          .read(groupServiceProvider)
          .sendGroupMessage(
            groupId: widget.groupId,
            text: fileName ?? '[$type]',
            type: type,
            mediaUrl: url,
            fileName: fileName,
            replyTo: _replyTo,
            isViewOnce: isViewOnce,
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

  void _showMediaSendPreviewSheet(File file, String type, {String? fileName}) {
    bool isViewOnce = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xFF0A1628),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.7,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.aquaCore.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      // Preview Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              type == 'video' ? 'Preview Video' : 'Preview Photo',
                              style: AppTextStyles.heading.copyWith(fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white70),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      // Media view container
                      Expanded(
                        child: Container(
                          color: Colors.black26,
                          width: double.infinity,
                          child: type == 'video'
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.video_library_rounded, color: AppColors.aquaCore.withOpacity(0.5), size: 64),
                                      const SizedBox(height: 12),
                                      Text(
                                        file.path.split('/').last,
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : Image.file(file, fit: BoxFit.contain),
                        ),
                      ),
                      // View-Once toggle bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // View Once badge button
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  isViewOnce = !isViewOnce;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isViewOnce
                                      ? AppColors.aquaCore.withOpacity(0.2)
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isViewOnce
                                        ? AppColors.aquaCore
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '1',
                                    style: TextStyle(
                                      color: isViewOnce
                                          ? AppColors.aquaCore
                                          : Colors.white70,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'View Once',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isViewOnce
                                        ? 'Recipient can open this media only once'
                                        : 'Send as standard media message',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            // Send action button
                            FloatingActionButton(
                              mini: true,
                              backgroundColor: AppColors.aquaCore,
                              child: const Icon(Icons.send_rounded, color: Colors.black),
                              onPressed: () {
                                Navigator.pop(context);
                                if (type == 'video') {
                                  _sendVideoMessage(file, isViewOnce: isViewOnce);
                                } else {
                                  _sendMediaMessage(file, type, fileName: fileName, isViewOnce: isViewOnce);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendLocationMessage(double lat, double lng, {bool isLive = false}) async {
    setState(() => _isSending = true);
    try {
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: isLive ? 'Live Location' : 'Static Location',
            type: isLive ? 'live_location' : 'location',
            mediaUrl: 'geo:$lat,$lng',
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send location: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendContactCard(String name, String uid) async {
    setState(() => _isSending = true);
    try {
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: name,
            type: 'contact',
            mediaUrl: uid,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send contact card: $e'),
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
      builder:
          (_) => GifPickerSheet(
            onGifSelected: (gifUrl, previewUrl) async {
              setState(() => _isSending = true);
              try {
                await ref
                    .read(groupServiceProvider)
                    .sendGroupMessage(
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

  // ── Sticker Picker ───────────────────────────────────────
  void _showStickerPicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StickerPickerSheet(
        onStickerSelected: (stickerEmoji) async {
          setState(() => _isSending = true);
          try {
            await ref.read(groupServiceProvider).sendGroupMessage(
                  groupId: widget.groupId,
                  text: stickerEmoji,
                  type: 'sticker',
                );
            _scrollToBottom();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to send sticker: $e'),
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

  // ── Phase 3: Circular Video Message Upload ───────────────
  Future<void> _sendCircularVideoMessage(
    String filePath,
    Duration duration,
  ) async {
    setState(() => _isSending = true);
    try {
      final videoFile = File(filePath);
      final chatService = ref.read(chatServiceProvider);

      // Upload circular video to Cloudinary
      final videoUrl = await CloudinaryService.uploadVideo(videoFile);
      if (videoUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Circular video upload failed'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
            'senderId': chatService.myUid,
            'type': 'circular_video',
            'mediaUrl': videoUrl,
            'duration': duration.inSeconds,
            'text': null,
            'createdAt': FieldValue.serverTimestamp(),
            'isDeleted': false,
            'isEdited': false,
            'isPinned': false,
            'isStarred': false,
            'isForwarded': false,
            'reactions': {},
            'seenBy': [chatService.myUid],
            'deletedFor': [],
            'starredBy': [],
          });

      // Update last message preview
      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .update({
            'lastMessage': '🎥 Circular video',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send circular video: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
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
  Future<void> _sendVideoMessage(File videoFile, {bool isViewOnce = false}) async {
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
          thumbUrl = await CloudinaryService.uploadImage(File(thumbnailPath));
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
            'isViewOnce': isViewOnce,
            'viewedBy': [],
          });

      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .update({
            'lastMessage': {
              'text': isViewOnce ? '🎬 View Once Video' : '🎬 Video',
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

  // ── Phase 3: Polls ────────────────────────────────────────

  void _showCreatePollSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => CreatePollSheet(
            onPollCreated:
                (question, options) => _sendPollMessage(question, options),
          ),
    );
  }

  Future<void> _sendPollMessage(String question, List<String> options) async {
    setState(() => _isSending = true);

    try {
      final myUid = ref.read(groupServiceProvider).myUid;
      final poll = PollModel(
        question: question,
        options: options,
        votes: {for (var i = 0; i < options.length; i++) i.toString(): []},
        createdAt: Timestamp.now(),
        creatorId: myUid,
      );

      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .add({
            'senderId': myUid,
            'type': 'poll',
            'text': null,
            'pollData': poll.toMap(),
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
              'text': '📊 Poll: $question',
              'senderId': myUid,
              'timestamp': FieldValue.serverTimestamp(),
              'type': 'poll',
            },
          });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post poll: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _onMessageTextChanged() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (selection.baseOffset > 0) {
      final textBeforeCursor = text.substring(0, selection.baseOffset);
      final lastAtIdx = textBeforeCursor.lastIndexOf('@');
      if (lastAtIdx != -1) {
        final textAfterAt = textBeforeCursor.substring(lastAtIdx + 1);
        if (!textAfterAt.contains(' ')) {
          setState(() {
            _showMentionsOverlay = true;
            _mentionFilter = textAfterAt;
          });
          return;
        }
      }
    }
    if (_showMentionsOverlay) {
      setState(() {
        _showMentionsOverlay = false;
        _mentionFilter = '';
      });
    }
  }

  Widget _buildMentionsOverlay(List<UserModel> list) {
    final query = _mentionFilter.toLowerCase();
    final filteredMembers = list.where((m) {
      if (m.uid == ref.read(groupServiceProvider).myUid) return false;
      return m.name.toLowerCase().contains(query);
    }).toList();

    if (filteredMembers.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xED0A1628),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: filteredMembers.length,
          itemBuilder: (context, i) {
            final m = filteredMembers[i];
            return ListTile(
              dense: true,
              leading: AquaAvatar(
                imageUrl: m.photoUrl,
                name: m.name,
                size: 28,
              ),
              title: Text(
                m.name,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                final text = _messageController.text;
                final selection = _messageController.selection;
                if (selection.baseOffset > 0) {
                  final textBeforeCursor = text.substring(0, selection.baseOffset);
                  final lastAtIdx = textBeforeCursor.lastIndexOf('@');
                  if (lastAtIdx != -1) {
                    final newText = text.replaceRange(lastAtIdx, selection.baseOffset, '@${m.name} ');
                    _messageController.text = newText;
                    _messageController.selection = TextSelection.fromPosition(
                      TextPosition(offset: lastAtIdx + m.name.length + 2),
                    );
                  }
                }
                setState(() {
                  _showMentionsOverlay = false;
                  _mentionFilter = '';
                });
              },
            );
          },
        ),
      ),
    );
  }
}
