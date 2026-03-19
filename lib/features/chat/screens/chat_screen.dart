import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/media_compressor.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calls/screens/daily_call_screen.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../services/message_actions_service.dart';
import '../widgets/forward_message_sheet.dart';
import '../widgets/gif_picker_sheet.dart';
import '../widgets/glass_input_bar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_context_menu.dart';
import '../widgets/pinned_message_banner.dart';
import '../services/chat_organisation_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/privacy_service.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/chat_theme_picker.dart';
import 'chat_media_gallery_screen.dart';
import 'video_player_screen.dart';
import '../../social/services/social_service.dart';
import '../../privacy/services/vanish_mode_service.dart';

/// 1-to-1 Chat Screen — PRD §6.3
/// Phase 1: context menu, reactions, reply, edit, delete, forward, pin,
/// star, multi-select, seen receipts
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

  // Phase 1 state
  ReplyData? _replyTo;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedMessageIds = {};

  // Phase 5 — AI state
  List<String> _smartReplies = [];
  bool _loadingSmartReplies = false;
  String? _lastSmartReplyMsgId;
  SpamResult? _spamWarning;

  // Phase 6 — Privacy state
  bool _incognitoKeyboard = false;
  int _selfDestructSeconds = 0;
  bool _canShowTyping = true;
  bool _vanishModeEnabled = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markAsRead(widget.chatId);
      // Also mark with Phase 1 seenBy
      MessageActionsService.markMessagesAsSeen(
        chatId: widget.chatId,
        currentUid: ref.read(chatServiceProvider).myUid,
        isGroup: false,
        selfDestructSeconds: _selfDestructSeconds,
      );

      // Load privacy settings
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

    // Capture reply before clearing
    final replyData = _replyTo;
    setState(() => _replyTo = null);

    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      final vmData = chatDoc.data()?['vanishMode'] as Map<String, dynamic>?;
      final expiresAt = VanishModeService.calculateExpiration(vmData);

      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: widget.chatId,
        text: text,
        replyTo: replyData,
        expiresAt: expiresAt,
      );

      final myUid = ref.read(chatServiceProvider).myUid;
      final newStreak = await SocialService.updateStreak(
        chatId: widget.chatId,
        senderId: myUid,
        recipientId: widget.partnerUid,
      );
      
      if (newStreak == 7 || newStreak == 30 || newStreak == 100) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🔥 Streak extended to $newStreak days!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }

      await SocialService.checkAndUnlock(
        uid: myUid,
        trigger: 'message_sent',
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
    if (text.isNotEmpty && _canShowTyping) {
      chatService.setTypingTo(widget.partnerUid);
    } else {
      chatService.clearTyping();
    }
  }

  // ── Phase 6 — Privacy helpers ──────────────────────────

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privacy = await PrivacyService.getPrivacySettings();

      // Load self-destruct timer for this chat
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats').doc(widget.chatId).get();
      final timer = chatDoc.data()?['selfDestructTimer'] as int? ?? 0;
      final vmData = chatDoc.data()?['vanishMode'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _incognitoKeyboard = prefs.getBool('incognito_keyboard') ?? false;
          _selfDestructSeconds = timer;
          _vanishModeEnabled = vmData?['enabled'] == true;
          final stealth = privacy['stealthMode'] as bool? ?? false;
          final typing = privacy['typingIndicator'] as bool? ?? true;
          _canShowTyping = !stealth && typing;
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
                    chatId: widget.chatId,
                    isGroup: false,
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

  // ── Phase 6 — Privacy helpers ──────────────────────────

  Future<void> _toggleVanishMode() async {
    final newState = !_vanishModeEnabled;
    setState(() => _vanishModeEnabled = newState);
    
    await VanishModeService.toggleVanishMode(
      chatId: widget.chatId,
      isGroup: false,
      enabled: newState,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newState ? 'Vanish Mode enabled 👻' : 'Vanish Mode disabled'),
        backgroundColor: newState ? Colors.purple : const Color(0xFF1A2A40),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Phase 1 helpers ────────────────────────────────────

  void _setReplyTo(MessageModel message) {
    setState(() {
      _replyTo = ReplyData(
        messageId: message.id,
        senderName: message.senderId ==
                ref.read(chatServiceProvider).myUid
            ? 'You'
            : widget.partnerName,
        text: message.text ?? '',
        type: message.type,
        mediaUrl: message.mediaUrl,
      );
    });
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
            hintStyle:
                AppTextStyles.caption.copyWith(color: AppColors.textMuted),
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
              borderSide: const BorderSide(color: AppColors.aquaCore),
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
                  chatId: widget.chatId,
                  messageId: message.id,
                  newText: newText,
                  isGroup: false,
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
        chatId: widget.chatId,
        messageId: id,
        isGroup: false,
      );
    }
    _exitMultiSelect();
  }

  Future<void> _starSelected() async {
    for (final id in _selectedMessageIds) {
      await MessageActionsService.toggleStarMessage(
        chatId: widget.chatId,
        messageId: id,
        isGroup: false,
      );
    }
    _exitMultiSelect();
  }

  void _showContextMenu(MessageModel message, bool isMyMessage) {
    showMessageContextMenu(
      context: context,
      message: message,
      isMyMessage: isMyMessage,
      chatId: widget.chatId,
      isGroup: false,
      currentUid: ref.read(chatServiceProvider).myUid,
      onReply: () => _setReplyTo(message),
      onEdit: isMyMessage ? () => _showEditDialog(message) : null,
      onDeleteForEveryone: () =>
          MessageActionsService.deleteForEveryone(
        chatId: widget.chatId,
        messageId: message.id,
        isGroup: false,
      ),
      onDeleteForMe: () => MessageActionsService.deleteForMe(
        chatId: widget.chatId,
        messageId: message.id,
        isGroup: false,
      ),
      onForward: () => _showForwardSheet(message),
      onPin: () => MessageActionsService.togglePinMessage(
        chatId: widget.chatId,
        messageId: message.id,
        pin: !message.isPinned,
        isGroup: false,
      ),
      onStar: () => MessageActionsService.toggleStarMessage(
        chatId: widget.chatId,
        messageId: message.id,
        isGroup: false,
      ),
      onSaveToBookmarks: () => ChatOrganisationService.saveMessage(
        originalChatId: widget.chatId,
        originalMessageId: message.id,
        messageData: message.toMap(),
        senderName: message.senderId,
        senderPhoto: '',
      ),
      onTranslate: () => _showTranslator(message),
      onExplain: !isMyMessage ? () => _showExplainer(message) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(chatPartnerProvider(widget.partnerUid));
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUser = ref.read(chatServiceProvider).myUid;

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

              // Pinned message banner
              PinnedMessageBanner(
                chatId: widget.chatId,
                isGroup: false,
                onTap: () {
                  // Could scroll to pinned message
                },
                onUnpin: () =>
                    MessageActionsService.togglePinMessage(
                  chatId: widget.chatId,
                  messageId: '',
                  pin: false,
                  isGroup: false,
                ),
              ),

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
                    // Check for self destructing messages
                    _checkSelfDestruct(msgs);

                    // Filter out expired and deleted messages
                    final now = DateTime.now();
                    final filtered = msgs.where((m) {
                      if (m.deletedFor.contains(currentUser)) return false;
                      // Vanish Mode check
                      if (m.expiresAt != null && m.expiresAt!.toDate().isBefore(now)) {
                        return false;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                Icons.chat_bubble_outline_rounded,
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 12),
                      itemCount: filtered.length +
                          (partner.valueOrNull?.isTypingTo ==
                                  currentUser
                              ? 1
                              : 0),
                      itemBuilder: (_, i) {
                        // Show typing indicator at the end
                        if (i == filtered.length) {
                          return const Padding(
                            padding: EdgeInsets.only(
                                left: 12, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TypingIndicator(),
                            ),
                          );
                        }

                        final msg = filtered[i];
                        final isMe =
                            msg.senderId == currentUser;

                        return MessageBubble(
                          message: msg,
                          isMe: isMe,
                          currentUid: currentUser,
                          chatId: widget.chatId,
                          isGroup: false,
                          isSelected: _selectedMessageIds
                              .contains(msg.id),
                          isMultiSelectMode: _isMultiSelectMode,
                          onLongPress: () {
                            if (_isMultiSelectMode) {
                              _toggleSelection(msg.id);
                            } else {
                              _showContextMenu(msg, isMe);
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

              // Input bar (hidden during multi-select)
              if (!_isMultiSelectMode) ...[

                // Smart replies chips
                if (_loadingSmartReplies)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Shimmer.fromColors(
                            baseColor: Colors.white12,
                            highlightColor: Colors.white24,
                            child: Container(
                              width: 80,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_smartReplies.isNotEmpty)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _smartReplies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final reply = _smartReplies[i];
                        return GestureDetector(
                          onTap: () {
                            _messageController.text = reply;
                            _messageController.selection =
                                TextSelection.fromPosition(
                                    TextPosition(offset: reply.length));
                            setState(() => _smartReplies = []);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: AppColors.aquaCore.withValues(alpha: 0.5)),
                              color: AppColors.aquaCore.withValues(alpha: 0.08),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('✨',
                                    style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(reply,
                                    style: TextStyle(
                                        color: AppColors.aquaCore,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Spam warning banner
                if (_spamWarning != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️',
                            style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Possible Spam Detected',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(_spamWarning!.reason,
                                  style: TextStyle(
                                      color: Colors.orange.shade200,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.orange, size: 18),
                          onPressed: () =>
                              setState(() => _spamWarning = null),
                        ),
                      ],
                    ),
                  ),

                // Self-destruct banner
                if (_vanishModeEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    color: Colors.purple.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Text('👻',
                            style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        const Text(
                          'Vanish Mode Active. New messages disappear after 24 hours.',
                          style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _toggleVanishMode,
                          child: const Text('Turn Off',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  )
                else if (_selfDestructSeconds > 0)
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
                              chatId: widget.chatId,
                              isGroup: false,
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

                GlassInputBar(
                  controller: _messageController,
                  onSend: _sendMessage,
                  onChanged: _onTextChanged,
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
                  onAiCompose: () => _showAiComposer(context),
                  onToneFix: () => _showToneFixer(context),
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
            onTap: () {
              // Forward first selected message
              // (could be improved to batch)
              _exitMultiSelect();
            },
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
            icon: const Icon(
                Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Avatar
          Hero(
            tag: 'chat_avatar_${widget.chatId}',
            child: AquaAvatar(
              imageUrl: widget.partnerPhoto,
              name: widget.partnerName,
              size: 36,
              showOnlineDot: true,
              isOnline:
                  partner.valueOrNull?.isOnline ?? false,
            ),
          ),

          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partnerName,
                  style: AppTextStyles.headingSmall
                      .copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                partner.when(
                  data: (p) {
                    if (p == null) {
                      return const SizedBox.shrink();
                    }
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
                            style:
                                AppTextStyles.caption.copyWith(
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
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 10),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) =>
                      const SizedBox.shrink(),
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
                      chatId: widget.chatId,
                      isGroup: false,
                    ),
                  ),
                );
              } else if (value == 'summary') {
                _showChatSummary();
              } else if (value == 'self_destruct') {
                _showSelfDestructPicker();
              } else if (value == 'theme') {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => ChatThemePicker(
                    chatId: widget.chatId,
                    onThemeChanged: () => setState(() {}),
                  ),
                );
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
              PopupMenuItem(
                value: 'summary',
                child: Row(
                  children: [
                    Icon(Icons.summarize_rounded,
                        color: AppColors.aquaCore, size: 20),
                    SizedBox(width: 12),
                    Text('Summarise Chat',
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
              const PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(Icons.palette_rounded,
                        color: AppColors.aquaCore, size: 20),
                    SizedBox(width: 12),
                    Text('Chat Theme',
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

  Future<void> _startCall({required bool isVideo}) async {
    final myUid = ref.read(chatServiceProvider).myUid;
    final callId = const Uuid().v4();

    try {
      final callerName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

      // Create call document in Firestore
      await FirebaseService.firestore
          .collection('calls')
          .doc(callId)
          .set({
        'callerId': myUid,
        'calleeId': widget.partnerUid,
        'callerName': callerName,
        'channelName': widget.chatId,
        'type': isVideo ? 'video' : 'audio',
        'isGroup': false,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DailyCallScreen(
              callId: callId,
              channelName: widget.chatId,
              currentUserId: myUid,
              currentUserName: ref.read(currentUserProvider).valueOrNull?.name ?? 'Me',
              otherUserName: widget.partnerName,
              otherUserId: widget.partnerUid,
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
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF0EA5E9),
                  onTap: () async {
                    Navigator.pop(ctx);
                    // Multi-image picker (up to 10)
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
              style:
                  AppTextStyles.caption.copyWith(fontSize: 11)),
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

      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: widget.chatId,
        text: fileName ?? '[$type]',
        type: type,
        mediaUrl: url,
        fileName: fileName,
        replyTo: _replyTo,
      );

      final myUid = ref.read(chatServiceProvider).myUid;
      await SocialService.checkAndUnlock(
        uid: myUid,
        trigger: 'image_sent', 
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
            final chatService = ref.read(chatServiceProvider);
            await chatService.sendMessage(
              chatId: widget.chatId,
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
      // Upload to Cloudinary as raw/auto
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

      final chatService = ref.read(chatServiceProvider);
      // Send as voice message with extra metadata fields
      await FirebaseService.chatsCollection
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': chatService.myUid,
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
        'seenBy': [chatService.myUid],
        'deletedFor': [],
        'starredBy': [],
      });

      // Update last message preview
      await FirebaseService.chatsCollection
          .doc(widget.chatId)
          .update({
        'lastMessage': '🎙️ Voice message',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      final myUid = ref.read(chatServiceProvider).myUid;
      await SocialService.checkAndUnlock(
        uid: myUid,
        trigger: 'voice_sent', 
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

  // ── Phase 2: Video with Thumbnail ───────────────────────
  Future<void> _sendVideoMessage(File videoFile) async {
    setState(() => _isSending = true);
    try {
      // Generate thumbnail
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
      } catch (_) {
        // Thumbnail generation failed — continue without
      }

      // Upload video
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

      final chatService = ref.read(chatServiceProvider);
      await FirebaseService.chatsCollection
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': chatService.myUid,
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
        'seenBy': [chatService.myUid],
        'deletedFor': [],
        'starredBy': [],
      });

      await FirebaseService.chatsCollection
          .doc(widget.chatId)
          .update({
        'lastMessage': '🎬 Video',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
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

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // PHASE 5 — AI FEATURES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<bool> _isAiFeatureEnabled(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? true;
  }

  void _checkAndLoadSmartReplies(List<MessageModel> messages) {
    if (messages.isEmpty) return;
    final last = messages.first;
    final currentUid = ref.read(chatServiceProvider).myUid;
    if (last.senderId == currentUid) {
      setState(() => _smartReplies = []);
      return;
    }
    if (last.id == _lastSmartReplyMsgId) return;
    _lastSmartReplyMsgId = last.id;
    _fetchSmartReplies(messages);
  }

  Future<void> _fetchSmartReplies(List<MessageModel> messages) async {
    final enabled = await _isAiFeatureEnabled('ai_smart_replies');
    if (!enabled) return;

    setState(() {
      _loadingSmartReplies = true;
      _smartReplies = [];
    });

    try {
      final currentUid = ref.read(chatServiceProvider).myUid;
      final myName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

      final history = messages
          .take(8)
          .toList()
          .reversed
          .map((m) => <String, String>{
                'role': m.senderId == currentUid ? 'user' : 'other',
                'text': m.text ?? '',
              })
          .where((m) => m['text']!.isNotEmpty)
          .toList();

      final replies = await AiService.smartReplies(
        chatHistory: history,
        myName: myName,
        otherName: widget.partnerName,
      );

      if (mounted) {
        setState(() {
          _smartReplies = replies;
          _loadingSmartReplies = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingSmartReplies = false);
    }
  }

  Future<void> _checkSelfDestruct(List<MessageModel> messages) async {
    final now = DateTime.now();
    for (final msg in messages) {
      if (msg.deleteAt != null && msg.deleteAt!.toDate().isBefore(now)) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId)
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

  void _showChatSummary() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.aquaCore),
              SizedBox(height: 16),
              Text('Summarising chat...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );

    try {
      final currentUid = ref.read(chatServiceProvider).myUid;
      final myName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

      final snap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final messages = snap.docs.reversed
          .map((d) => <String, String>{
                'sender': d.data()['senderId'] == currentUid
                    ? myName
                    : widget.partnerName,
                'text': d.data()['text'] as String? ?? '',
              })
          .where((m) => m['text']!.isNotEmpty)
          .toList();

      final summary = await AiService.summariseChat(
        messages: messages,
        chatName: widget.partnerName,
      );

      await SocialService.checkAndUnlock(
        uid: currentUid,
        trigger: 'ai_used',
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('📋', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Text('Chat Summary',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ]),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: SingleChildScrollView(
                      child: Text(summary,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: summary));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Summary copied!')));
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.copy, size: 14, color: AppColors.aquaCore),
                      const SizedBox(width: 6),
                      Text('Copy Summary',
                          style: TextStyle(color: AppColors.aquaCore)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Summary failed: $e')));
      }
    }
  }

  void _showTranslator(MessageModel message) {
    String? translation;
    bool isLoading = false;
    String selectedLang = 'English';

    final languages = [
      'English', 'Hindi', 'Telugu', 'Tamil', 'Spanish', 'French',
      'German', 'Japanese', 'Korean', 'Arabic', 'Portuguese', 'Italian',
      'Russian', 'Chinese', 'Turkish',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> translate(String lang) async {
            setModal(() {
              isLoading = true;
              selectedLang = lang;
            });
            try {
              final result = await AiService.translateMessage(
                text: message.text ?? '',
                targetLanguage: lang,
              );

              final myUid = ref.read(chatServiceProvider).myUid;
              await SocialService.checkAndUnlock(
                uid: myUid,
                trigger: 'translator_used',
              );

              setModal(() {
                translation = result;
                isLoading = false;
              });
            } catch (e) {
              setModal(() => isLoading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Text('🌍', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('Translate',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(message.text ?? '',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 14)),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: languages
                      .map((lang) => GestureDetector(
                            onTap: () => translate(lang),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: selectedLang == lang
                                    ? AppColors.aquaCore.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.05),
                                border: Border.all(
                                    color: selectedLang == lang
                                        ? AppColors.aquaCore
                                        : Colors.white24),
                              ),
                              child: Text(lang,
                                  style: TextStyle(
                                      color: selectedLang == lang
                                          ? AppColors.aquaCore
                                          : Colors.white60,
                                      fontSize: 13)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  Shimmer.fromColors(
                    baseColor: Colors.white12,
                    highlightColor: Colors.white24,
                    child: Container(
                      height: 60,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else if (translation != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.aquaCore.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.aquaCore.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🌍 $selectedLang',
                            style: TextStyle(
                                color: AppColors.aquaCore,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(translation!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showToneFixer(BuildContext ctx) {
    final originalText = _messageController.text.trim();
    if (originalText.isEmpty) return;

    String rewrittenText = '';
    bool isLoading = false;
    String? selectedTone;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (bCtx, setModal) {
          Future<void> applyTone(String tone) async {
            setModal(() {
              isLoading = true;
              selectedTone = tone;
            });
            try {
              final result =
                  await AiService.fixTone(text: originalText, tone: tone);
                  
              final myUid = ref.read(chatServiceProvider).myUid;
              await SocialService.checkAndUnlock(
                uid: myUid,
                trigger: 'ai_used',
              );

              setModal(() {
                rewrittenText = result;
                isLoading = false;
              });
            } catch (e) {
              setModal(() => isLoading = false);
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Text('✨', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('AI Tone Fixer',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(originalText,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _toneChip('💼', 'Formal', 'formal', selectedTone, isLoading,
                        () => applyTone('formal')),
                    _toneChip('😊', 'Friendly', 'friendly', selectedTone,
                        isLoading, () => applyTone('friendly')),
                    _toneChip('😂', 'Funny', 'funny', selectedTone, isLoading,
                        () => applyTone('funny')),
                    _toneChip('✂️', 'Shorter', 'shorter', selectedTone,
                        isLoading, () => applyTone('shorter')),
                    _toneChip('📝', 'Longer', 'longer', selectedTone, isLoading,
                        () => applyTone('longer')),
                    _toneChip('✅', 'Fix Grammar', 'grammar', selectedTone,
                        isLoading, () => applyTone('grammar')),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading && rewrittenText.isEmpty)
                  Shimmer.fromColors(
                    baseColor: Colors.white12,
                    highlightColor: Colors.white24,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  )
                else if (rewrittenText.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.aquaCore.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.aquaCore.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('✨ Rewritten',
                            style: TextStyle(
                                color: AppColors.aquaCore,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(rewrittenText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _messageController.text = rewrittenText;
                      _messageController.selection =
                          TextSelection.fromPosition(
                              TextPosition(offset: rewrittenText.length));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aquaCore,
                        minimumSize: const Size(double.infinity, 48)),
                    child: const Text('Use This Message'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _toneChip(String emoji, String label, String tone,
      String? selectedTone, bool isLoading, VoidCallback onTap) {
    final isSelected = selectedTone == tone;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? AppColors.aquaCore.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
              color: isSelected ? AppColors.aquaCore : Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            (isLoading && isSelected)
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.aquaCore))
                : Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: isSelected ? AppColors.aquaCore : Colors.white70,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  void _showAiComposer(BuildContext ctx) {
    final instructionController = TextEditingController();
    bool isLoading = false;
    String? composed;

    final suggestions = [
      'Accept the invitation',
      'Politely decline',
      'Ask for more details',
      'Apologise for the delay',
      'Confirm the meeting time',
      'Congratulate them',
      'Ask to reschedule',
      'Express excitement',
    ];

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (bCtx, setModal) {
          Future<void> compose(String instruction) async {
            setModal(() => isLoading = true);
            try {
              final currentUid = ref.read(chatServiceProvider).myUid;
              final myName =
                  ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

              final snap = await FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .get();

              final history = snap.docs.reversed
                  .map((d) => {
                        'role': d.data()['senderId'] == currentUid
                            ? 'user'
                            : 'other',
                        'text': d.data()['text'] as String? ?? '',
                      })
                  .where((m) => (m['text'] as String).isNotEmpty)
                  .toList();

              final result = await AiService.composeReply(
                instruction: instruction,
                chatHistory: history,
                myName: myName,
                otherName: widget.partnerName,
              );

              final myUid = ref.read(chatServiceProvider).myUid;
              await SocialService.checkAndUnlock(
                uid: myUid,
                trigger: 'ai_used',
              );

              setModal(() {
                composed = result;
                isLoading = false;
              });
            } catch (e) {
              setModal(() => isLoading = false);
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Text('🤖', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('AI Compose',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                const Text('Describe what you want to say',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions
                      .map((s) => GestureDetector(
                            onTap: () {
                              instructionController.text = s;
                              compose(s);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withValues(alpha: 0.05),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(s,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: instructionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Or type your own...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final instruction = instructionController.text.trim();
                      if (instruction.isNotEmpty) compose(instruction);
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: AppColors.aquaCore, shape: BoxShape.circle),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                if (composed != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.aquaCore.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.aquaCore.withValues(alpha: 0.3)),
                    ),
                    child: Text(composed!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, height: 1.4)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _messageController.text = composed!;
                      _messageController.selection =
                          TextSelection.fromPosition(
                              TextPosition(offset: composed!.length));
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.aquaCore,
                        minimumSize: const Size(double.infinity, 48)),
                    child: const Text('Use Message'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showExplainer(MessageModel message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.aquaCore),
              SizedBox(height: 16),
              Text('Analysing message...',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );

    try {
      final explanation = await AiService.explainMessage(
        text: message.text ?? '',
        senderName: widget.partnerName,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Text('Message Explained',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ]),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('"${message.text}"',
                        style: const TextStyle(
                            color: Colors.white60,
                            fontStyle: FontStyle.italic,
                            fontSize: 13)),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35),
                    child: SingleChildScrollView(
                      child: Text(explanation,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not explain: $e')));
      }
    }
  }
}
