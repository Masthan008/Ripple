import '../../../core/utils/haptic_feedback.dart';
import '../../groups/widgets/create_poll_sheet.dart';
import '../../groups/models/poll_model.dart';
import 'cloud_drive_screen.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import '../../../core/services/decoy_matrix_generator.dart';
import '../../../core/services/steganography_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart'; // Add this
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../status/services/status_service.dart';
import '../../../shared/widgets/aurora_background.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/media_compressor.dart';
import '../../profile/providers/settings_provider.dart'; // Add this
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
import '../widgets/custom_notifications_picker.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../stickers/widgets/sticker_picker_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_context_menu.dart';
import '../widgets/pinned_message_banner.dart';
import '../services/chat_organisation_service.dart';
import '../services/schedule_service.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/privacy_service.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/chat_theme_picker.dart';
import '../services/chat_theme_service.dart';
import 'chat_media_gallery_screen.dart';
import '../widgets/location_selector_sheet.dart';
import '../widgets/contact_selector_sheet.dart';
import '../../social/services/social_service.dart';
import '../../privacy/services/vanish_mode_service.dart';
import '../widgets/gaze_lock_overlay.dart';
import '../providers/gaze_privacy_provider.dart';
import '../widgets/sensory_text_controller.dart';
import '../../../core/services/chronos_unlock_service.dart';
import '../../../core/services/notification_service.dart';
import '../widgets/chronos_composer_sheet.dart';
import '../../../shared/widgets/keyword_particle_overlay.dart';
import '../../../core/services/sentience_engine.dart';
import '../widgets/quantum_vault_bubble.dart';
import '../widgets/sonic_whisper_overlay.dart';
import '../../../shared/widgets/sentient_breathing_wrapper.dart';
import '../../../shared/widgets/gyroscopic_parallax.dart';
import '../../../shared/widgets/liquid_glass_container.dart';

/// 1-to-1 Chat Screen — PRD §6.3
/// Phase 1: context menu, reactions, reply, edit, delete, forward, pin,
/// star, multi-select, seen receipts
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String partnerUid;
  final String partnerName;
  final String? partnerPhoto;
  final bool isDecoy;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.partnerUid,
    required this.partnerName,
    this.partnerPhoto,
    this.isDecoy = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final String _chatId;
  bool _disposed = false;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final SensoryTextController _sensoryController;
  StreamSubscription? _privacySubscription;
  bool _isSending = false;
  bool _showEmojiPicker = false;

  // Decoy messages state
  List<MessageModel> _decoyMessages = [];

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

  bool _isSummarizing = false;

  // Chronos Messaging™ state
  String? _chronosConditionType;
  String? _chronosConditionValue;

  // Keyword Particle System
  String? _lastSentText;

  // Quantum Vault™ state
  bool _isQuantumLocked = false;

  bool _isMuted = false;

  // In-Chat Search state
  bool _isSearching = false;
  final _searchController = TextEditingController();

  // Applied chat wallpaper theme (instant local feedback)
  List<Color>? _appliedWallpaperColors;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId.isNotEmpty
        ? widget.chatId
        : ref.read(chatServiceProvider).getChatId(widget.partnerUid);
    _sensoryController = SensoryTextController(controller: _messageController);
    // Track active chat for foreground notification suppression
    NotificationService.currentActiveChatId = _chatId;

    if (widget.isDecoy) {
      final decoyChat = DecoyMatrixGenerator.getDecoyChats().firstWhere(
        (c) => c['id'] == _chatId,
        orElse: () => <String, dynamic>{},
      );
      final myUid = ref.read(chatServiceProvider).myUid;
      if (decoyChat['messages'] is List) {
        final messagesList = decoyChat['messages'] as List;
        _decoyMessages = messagesList.map((m) {
          final map = m as Map<String, dynamic>;
          return MessageModel(
            id: 'decoy_msg_${const Uuid().v4()}',
            senderId: map['senderId'] == 'current_user' ? myUid : map['senderId'] as String,
            text: map['text'] as String,
            type: 'text',
            createdAt: DateTime.now().subtract(Duration(minutes: messagesList.length - messagesList.indexOf(m))),
            seenBy: [myUid],
          );
        }).toList();
      }
    }
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markAsRead(_chatId);
      // Also mark with Phase 1 seenBy
      MessageActionsService.markMessagesAsSeen(
        chatId: _chatId,
        currentUid: ref.read(chatServiceProvider).myUid,
        isGroup: false,
        selfDestructSeconds: _selfDestructSeconds,
      );

      // Load privacy settings
      _loadPrivacySettings();

      // Start Chronos™ unlock monitoring
      ChronosUnlockService.instance.startMonitoring(
        chatId: _chatId,
        currentUid: ref.read(chatServiceProvider).myUid,
        isGroup: false,
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // Cancel Firestore privacy listener FIRST to stop callbacks
    _privacySubscription?.cancel();
    _privacySubscription = null;
    // Clear typing status while ref is still valid (before super.dispose)
    try {
      ref.read(chatServiceProvider).clearTyping();
    } catch (_) {}
    NotificationService.currentActiveChatId = null;
    _sensoryController.dispose();
    ChronosUnlockService.instance.stopMonitoring();
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

  Future<void> _handleRippleBotCommand(String text) async {
    final query = text.replaceAll('@ripple', '').trim();
    if (query.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final messages = ref.read(chatMessagesProvider(_chatId)).valueOrNull ?? [];
      final chatContext = messages.take(20).map((m) => {
        'sender': m.senderId == widget.partnerUid ? widget.partnerName : 'You',
        'text': m.text ?? '',
      }).toList();

      final response = await AiService.rippleBotAssistant(
        query: query,
        chatContext: chatContext,
      );

      // Send the bot response as a message
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: _chatId,
        text: '🤖 Ripple Bot: $response',
        replyTo: null,
        expiresAt: null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ripple Bot error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (widget.isDecoy) {
      setState(() => _isSending = true);
      _messageController.clear();
      setState(() => _replyTo = null);
      await _sendDecoyMessage(text);
      setState(() => _isSending = false);
      return;
    }

    // Check for @ripple bot command
    if (text.contains('@ripple')) {
      await _handleRippleBotCommand(text);
      _messageController.clear();
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    // Trigger keyword particle system
    setState(() => _lastSentText = text);

    // Capture reply before clearing
    final replyData = _replyTo;
    setState(() => _replyTo = null);

    try {
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatId)
              .get();

      final vmData = chatDoc.data()?['vanishMode'] as Map<String, dynamic>?;
      final expiresAt = VanishModeService.calculateExpiration(vmData);

      // Capture emotional signature before clearing controller
      final emotionalSignature = _sensoryController.captureSignature();

      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: _chatId,
        text: text,
        replyTo: replyData,
        expiresAt: expiresAt,
        emotionalSignature: emotionalSignature,
        chronosConditionType: _chronosConditionType,
        chronosConditionValue: _chronosConditionValue,
        isChronosLocked: _chronosConditionType != null,
        isQuantumLocked: _isQuantumLocked,
      );

      // Reset chronos and quantum state after send
      setState(() {
        _chronosConditionType = null;
        _chronosConditionValue = null;
        _isQuantumLocked = false;
      });

      final myUid = ref.read(chatServiceProvider).myUid;
      final newStreak = await SocialService.updateStreak(
        chatId: _chatId,
        senderId: myUid,
        recipientId: widget.partnerUid,
      );

      if (newStreak == 7 || newStreak == 30 || newStreak == 100) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔥 Streak extended to $newStreak days!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      await SocialService.checkAndUnlock(uid: myUid, trigger: 'message_sent');

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
    if (!_canShowTyping) return;

    final chatService = ref.read(chatServiceProvider);
    if (text.isNotEmpty) {
      chatService.setTypingTo(widget.partnerUid);
    } else {
      chatService.clearTyping();
    }
  }

  // ── Phase 6 — Privacy helpers ──────────────────────────

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Watch privacy settings for real-time updates
      // Cancel any previous subscription before creating a new one
      _privacySubscription?.cancel();
      _privacySubscription = FirebaseService.firestore
          .collection('users')
          .doc(ref.read(chatServiceProvider).myUid)
          .snapshots()
          .listen((snap) {
            if (!mounted || _disposed) return;
            final data = snap.data() as Map<String, dynamic>?;
            final privacy = data?['privacy'] as Map<String, dynamic>? ?? {};

            final mutedChats =
                Map<String, dynamic>.from(data?['mutedChats'] as Map? ?? {});
            bool currentlyMuted = false;
            if (mutedChats.containsKey(_chatId)) {
              final expiryStr = mutedChats[_chatId] as String?;
              if (expiryStr == 'always') {
                currentlyMuted = true;
              } else if (expiryStr != null) {
                final expiry = DateTime.tryParse(expiryStr);
                if (expiry != null && expiry.isAfter(DateTime.now())) {
                  currentlyMuted = true;
                }
              }
            }

            setState(() {
              _incognitoKeyboard = prefs.getBool('incognito_keyboard') ?? false;
              final stealth = privacy['stealthMode'] as bool? ?? false;
              final typing = privacy['typingIndicator'] as bool? ?? true;
              _canShowTyping = !stealth && typing;
              _isMuted = currentlyMuted;
            });
          });

      // Load self-destruct timer for this chat
      final chatDoc =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatId)
              .get();
      final timer = chatDoc.data()?['selfDestructTimer'] as int? ?? 0;
      final vmData = chatDoc.data()?['vanishMode'] as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _selfDestructSeconds = timer;
          _vanishModeEnabled = vmData?['enabled'] == true;
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
                      chatId: _chatId,
                      isGroup: false,
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

  // ── Phase 6 — Privacy helpers ──────────────────────────

  Future<void> _toggleVanishMode() async {
    final newState = !_vanishModeEnabled;
    setState(() => _vanishModeEnabled = newState);

    await VanishModeService.toggleVanishMode(
      chatId: _chatId,
      isGroup: false,
      enabled: newState,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState ? 'Vanish Mode enabled 👻' : 'Vanish Mode disabled',
          ),
          backgroundColor: newState ? Colors.purple : const Color(0xFF1A2A40),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Phase 1 helpers ────────────────────────────────────

  void _setReplyTo(MessageModel message) {
    setState(() {
      _replyTo = ReplyData(
        messageId: message.id,
        senderName:
            message.senderId == ref.read(chatServiceProvider).myUid
                ? 'You'
                : widget.partnerName,
        text: message.text ?? '',
        type: message.type,
        mediaUrl: message.mediaUrl,
      );
    });
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
                      chatId: _chatId,
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
        chatId: _chatId,
        messageId: id,
        isGroup: false,
      );
    }
    _exitMultiSelect();
  }

  Future<void> _starSelected() async {
    for (final id in _selectedMessageIds) {
      await MessageActionsService.toggleStarMessage(
        chatId: _chatId,
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
      chatId: _chatId,
      isGroup: false,
      currentUid: ref.read(chatServiceProvider).myUid,
      onReply: () => _setReplyTo(message),
      onEdit: isMyMessage ? () => _showEditDialog(message) : null,
      onDeleteForEveryone:
          () => MessageActionsService.deleteForEveryone(
            chatId: _chatId,
            messageId: message.id,
            isGroup: false,
          ),
      onDeleteForMe:
          () => MessageActionsService.deleteForMe(
            chatId: _chatId,
            messageId: message.id,
            isGroup: false,
          ),
      onForward: () => _showForwardSheet(message),
      onPin:
          () => MessageActionsService.togglePinMessage(
            chatId: _chatId,
            messageId: message.id,
            pin: !message.isPinned,
            isGroup: false,
          ),
      onStar:
          () => MessageActionsService.toggleStarMessage(
            chatId: _chatId,
            messageId: message.id,
            isGroup: false,
          ),
      onSaveToBookmarks:
          () => ChatOrganisationService.saveMessage(
            originalChatId: _chatId,
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
    final messages = widget.isDecoy
        ? AsyncValue.data(_decoyMessages)
        : ref.watch(chatMessagesProvider(_chatId));
    final currentUser = ref.read(chatServiceProvider).myUid;
    final currentTheme = ref.watch(themeProvider);

    // Auto-scroll on new messages
    messages.whenData((_) => _scrollToBottom());

    // Theme logic
    Color bgColor = AppColors.abyssBackground;
    if (currentTheme == 'light_glass') bgColor = const Color(0xFFF0F9FF);
    if (currentTheme == 'midnight_purple') bgColor = const Color(0xFF0F001A);

    final sentienceState = ref.watch(sentienceProvider(_chatId));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ChatThemeService.getThemeStream(_chatId),
      builder: (context, snapshot) {
        final themeData = snapshot.data?.data();
        List<Color>? wallpaperColors;
        String? solidColorHex;
        String? imageUrl;
        double dimValue = 0.45;

        if (themeData != null) {
          dimValue = (themeData['dimValue'] as num?)?.toDouble() ?? 0.45;
          if (themeData['imageUrl'] != null) {
            imageUrl = themeData['imageUrl'] as String?;
          } else if (themeData['solidColor'] != null) {
            solidColorHex = themeData['solidColor'] as String?;
          } else if (themeData['gradientColors'] != null) {
            final gradientColors = themeData['gradientColors'] as List? ?? [];
            wallpaperColors = gradientColors
                .map((c) => Color(int.parse('FF$c', radix: 16)))
                .toList();
          }
        }
        final activeWallpaper = _appliedWallpaperColors ??
            (wallpaperColors != null && wallpaperColors.isNotEmpty
                ? wallpaperColors
                : null);

        return Scaffold(
          backgroundColor: bgColor,
          body: SentientBreathingWrapper(
            chatId: _chatId,
            child: Stack(
              children: [
                // Background Layer
                if (imageUrl != null) ...[
                  Positioned.fill(
                    child: Container(color: bgColor),
                  ),
                  Positioned.fill(
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: bgColor),
                      errorWidget: (context, url, error) => Container(color: bgColor),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(dimValue), // Dynamic dimming overlay
                    ),
                  ),
                ] else if (solidColorHex != null) ...[
                  Positioned.fill(
                    child: Container(
                      color: Color(int.parse('FF$solidColorHex', radix: 16)),
                    ),
                  ),
                ] else ...[
                  Positioned.fill(
                    child: AuroraBackground(
                      customColors: sentienceState.intensity > 0
                          ? [
                              sentienceState.primaryGlow,
                              sentienceState.secondaryGlow,
                              sentienceState.accentGlow
                            ]
                          : activeWallpaper,
                      animationSpeed: sentienceState.animationSpeed,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],

                // Foreground Content Stack
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Gyroscopic parallax floating particles
                      ParallaxLayer(
                        depthFactor: 1.5,
                        child: FloatingParticles(
                          particleCount: 3,
                          color: currentTheme == 'light_glass'
                              ? AppColors.aquaCore.withOpacity(0.3)
                              : AppColors.aquaCore,
                        ),
                      ),

                      Column(
                        children: [
              // Header
              _buildHeader(partner),

              // Pinned message banner
              PinnedMessageBanner(
                chatId: _chatId,
                isGroup: false,
                onTap: () {
                  // Could scroll to pinned message
                },
                onUnpin:
                    () => MessageActionsService.togglePinMessage(
                      chatId: _chatId,
                      messageId: '',
                      pin: false,
                      isGroup: false,
                    ),
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
                    // Defer side-effects to after build to avoid
                    // infinite rebuild loops (especially on new/empty chats)
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _disposed) return;
                      // Check for self destructing messages
                      _checkSelfDestruct(msgs);

                      // Load AI smart replies for the latest incoming message
                      _checkAndLoadSmartReplies(msgs);

                      // Sentience Engine™ — analyze emotional tone
                      if (msgs.isNotEmpty) {
                        final recentTexts = msgs
                            .take(5)
                            .where((m) => m.text != null && m.text!.isNotEmpty)
                            .map((m) => <String, String>{
                                  'sender': m.senderId == currentUser ? 'Me' : widget.partnerName,
                                  'text': m.text!,
                                })
                            .toList()
                            .reversed
                            .toList();
                        ref.read(sentienceProvider(_chatId).notifier)
                            .analyze(recentTexts, msgs.first.id);
                      }
                    });

                    // Filter out expired and deleted messages
                    final now = DateTime.now();
                    var filtered =
                        msgs.where((m) {
                          if (m.deletedFor.contains(currentUser)) return false;
                          // Vanish Mode check
                          if (m.expiresAt != null &&
                              m.expiresAt!.toDate().isBefore(now)) {
                            return false;
                          }
                          return true;
                        }).toList();

                    // Local message search filter
                    if (_isSearching && _searchController.text.isNotEmpty) {
                      final query = _searchController.text.toLowerCase();
                      filtered = filtered.where((m) {
                        return m.text != null && m.text!.toLowerCase().contains(query);
                      }).toList();
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: AppColors.aquaCore.withValues(alpha: 0.2),
                              size: 64,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Say hello! 👋',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }

                    return AnimationLimiter(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          AppHaptics.mediumTap();
                          // Trigger reload by refreshing providers if needed,
                          // or just simulate work for the "Liquid" effect.
                          await Future.delayed(const Duration(seconds: 1));
                          ref.invalidate(chatMessagesProvider(_chatId));
                        },
                        color: AppColors.aquaCore,
                        backgroundColor: AppColors.abyssBackground.withOpacity(
                          0.8,
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          itemCount:
                              filtered.length +
                              (partner.valueOrNull?.isTypingTo == currentUser
                                  ? 1
                                  : 0),
                          itemBuilder: (_, i) {
                            final isFirstInSequence = i == 0 || 
                                (i > 0 && i < filtered.length && filtered[i].senderId != filtered[i - 1].senderId);
                            final isLastInSequence = i == filtered.length - 1 || 
                                (i < filtered.length - 1 && filtered[i].senderId != filtered[i + 1].senderId);

                            return AnimationConfiguration.staggeredList(
                              position: i,
                              duration: const Duration(milliseconds: 400),
                              child: SlideAnimation(
                                verticalOffset: 20.0,
                                curve: Curves.easeOutCubic,
                                child: FadeInAnimation(
                                  child:
                                      i == filtered.length
                                          ? const Padding(
                                            padding: EdgeInsets.only(
                                              left: 12,
                                              bottom: 8,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: TypingIndicator(),
                                            ),
                                          )
                                          : MessageBubble(
                                            message: filtered[i],
                                            isMe:
                                                filtered[i].senderId ==
                                                currentUser,
                                            currentUid: currentUser,
                                            chatId: _chatId,
                                            isGroup: false,
                                            isSelected: _selectedMessageIds
                                                .contains(filtered[i].id),
                                            isMultiSelectMode:
                                                _isMultiSelectMode,
                                            isFirstInSequence: isFirstInSequence,
                                            isLastInSequence: isLastInSequence,
                                            onLongPress: () {
                                              if (_isMultiSelectMode) {
                                                _toggleSelection(
                                                  filtered[i].id,
                                                );
                                              } else {
                                                _showContextMenu(
                                                  filtered[i],
                                                  filtered[i].senderId ==
                                                      currentUser,
                                                );
                                              }
                                            },
                                            onTap:
                                                _isMultiSelectMode
                                                    ? () => _toggleSelection(
                                                      filtered[i].id,
                                                    )
                                                    : null,
                                          ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Multi-select bottom bar
              if (_isMultiSelectMode) _buildMultiSelectBar(),

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
                            _messageController
                                .selection = TextSelection.fromPosition(
                              TextPosition(offset: reply.length),
                            );
                            setState(() => _smartReplies = []);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.aquaCore.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              color: AppColors.aquaCore.withValues(alpha: 0.08),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  reply,
                                  style: TextStyle(
                                    color: AppColors.aquaCore,
                                    fontSize: 13,
                                  ),
                                ),
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
                        color: Colors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Possible Spam Detected',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _spamWarning!.reason,
                                style: TextStyle(
                                  color: Colors.orange.shade200,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.orange,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _spamWarning = null),
                        ),
                      ],
                    ),
                  ),

                // Self-destruct banner
                if (_vanishModeEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: Colors.purple.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Text('👻', style: TextStyle(fontSize: 14)),
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
                          child: const Text(
                            'Turn Off',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_selfDestructSeconds > 0)
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
                              chatId: _chatId,
                              isGroup: false,
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

                // Chronos\u2122 condition banner
                if (_chronosConditionType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Row(
                      children: [
                        Icon(
                          ChronosUnlockService.conditionIcons[_chronosConditionType!] ?? Icons.hourglass_empty,
                          size: 16,
                          color: const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chronos: ${ChronosUnlockService.formatCondition(
                              _chronosConditionType!,
                              _chronosConditionValue ?? '',
                            )}',
                            style: TextStyle(
                              color: const Color(0xFF6366F1).withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _chronosConditionType = null;
                            _chronosConditionValue = null;
                          }),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF6366F1),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                LiquidGlassContainer(
                  scrollController: _scrollController,
                  baseBlur: 18,
                  borderRadius: 0,
                  glassColor: const Color(0xE6060D1A),
                  child: GlassInputBar(
                  controller: _messageController,
                  onSend: _sendMessage,
                  onChanged: _onTextChanged,
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
                  onAiCompose: () => _showAiComposer(context),
                  onToneFix: () => _showToneFixer(context),
                  onSchedule: () => _showChronosComposer(context),
                  onSticker: () => _showStickerPicker(context),
                  isQuantumLocked: _isQuantumLocked,
                  onQuantumToggle: () {
                    setState(() => _isQuantumLocked = !_isQuantumLocked);
                    AppHaptics.mediumTap();
                  },
                ),
                ), // end LiquidGlassContainer

                // Quantum Vault™ active banner
                if (_isQuantumLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(
                          'Quantum Vault active — message will be scrambled',
                          style: TextStyle(
                            color: const Color(0xFF6366F1).withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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

          // Keyword Particle Overlay — emotional emoji particles
          KeywordParticleOverlay(triggerKeyword: _lastSentText),
        ],
      ),
      ),
      ],
      ),
      ),
    );
      },
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

  Widget _buildHeader(AsyncValue<UserModel?> partner) {
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
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Avatar
          Hero(
            tag: 'chat_avatar_${_chatId}',
            child: AquaAvatar(
              imageUrl: widget.partnerPhoto,
              name: widget.partnerName,
              size: 36,
              showOnlineDot: true,
              isOnline: partner.valueOrNull?.isOnline ?? false,
            ),
          ),

          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        widget.partnerName,
                        style: AppTextStyles.headingSmall.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    VerifiedBadge(
                      isVerified: partner.valueOrNull?.isVerified ?? false,
                      userId: widget.partnerUid,
                      plan: partner.valueOrNull?.subscriptionPlan,
                      size: 14,
                    ),
                  ],
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
                            L10n.s(ref, 'online'),
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

          // Catch up / Summarize button
          GestureDetector(
            onTap: _isSummarizing ? null : _summarizeConversation,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.glassPanel,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child:
                  _isSummarizing
                      ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.aquaCore,
                        ),
                      )
                      : const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.aquaCore,
                        size: 18,
                      ),
            ),
          ),

          const SizedBox(width: 8),

          // Video call button
          GestureDetector(
            onTap: () => _startCall(isVideo: true),
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
                border: Border.all(color: AppColors.glassBorder, width: 0.5),
              ),
              child: const Icon(
                Icons.call_rounded,
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
                          chatId: _chatId,
                          isGroup: false,
                        ),
                  ),
                );
              } else if (value == 'summary') {
                _showChatSummary();
              } else if (value == 'self_destruct') {
                _showSelfDestructPicker();
              } else if (value == 'theme') {
                final currentUser = ref.read(currentUserProvider).value;
                final plan = currentUser?.subscriptionPlan ?? '';
                if (plan != 'Premium Trial' && plan != 'Gold Monthly' && plan != 'Abyss Platinum') {
                  _showUpgradeRequiredDialog(
                    context,
                    title: 'Unlock Chat Themes',
                    message: 'Custom chat backgrounds, colors, and premium glass presets are available on the Gold Monthly and Abyss Platinum subscription plans. Start your 1-month Free Trial to unlock them today!',
                  );
                  return;
                }
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder:
                      (_) => ChatThemePicker(
                        chatId: _chatId,
                        onThemeChanged: (colors) {
                          setState(() => _appliedWallpaperColors = colors);
                        },
                      ),
                );
              } else if (value == 'export') {
                _exportChat();
              } else if (value == 'mute') {
                NotificationService.showMuteDialog(context, _chatId);
              } else if (value == 'unmute') {
                NotificationService.unmuteChat(_chatId);
              } else if (value == 'custom_sound') {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder:
                      (_) => CustomNotificationsPicker(
                        chatId: _chatId,
                        partnerName: widget.partnerName,
                      ),
                );
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
                  PopupMenuItem(
                    value: 'summary',
                    child: Row(
                      children: [
                        Icon(
                          Icons.summarize_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Summarise Chat',
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
                    value: 'theme',
                    child: Row(
                      children: [
                        Icon(
                          Icons.palette_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Chat Theme',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(
                          Icons.import_export_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Export Chat',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _isMuted ? 'unmute' : 'mute',
                    child: Row(
                      children: [
                        Icon(
                          _isMuted
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isMuted
                              ? 'Unmute Notifications'
                              : 'Mute Notifications',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'custom_sound',
                    child: Row(
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          color: AppColors.aquaCore,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Custom Notifications',
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

  Future<void> _startCall({required bool isVideo}) async {
    final myUid = ref.read(chatServiceProvider).myUid;
    final callId = const Uuid().v4();

    try {
      final callerName =
          ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

      // Create call document in Firestore
      await FirebaseService.firestore.collection('calls').doc(callId).set({
        'callerId': myUid,
        'calleeId': widget.partnerUid,
        'callerName': callerName,
        'channelName': _chatId,
        'type': isVideo ? 'video' : 'audio',
        'isGroup': false,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => DailyCallScreen(
                  callId: callId,
                  channelName: _chatId,
                  currentUserId: myUid,
                  currentUserName:
                      ref.read(currentUserProvider).valueOrNull?.name ?? 'Me',
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
                        // Multi-image picker (up to 10)
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
                        Navigator.pop(context);
                        _showCreatePollSheet();
                      },
                    ),
                    _attachOption(
                      icon: Icons.cloud_done_rounded,
                      label: 'Drive',
                      color: const Color(0xFF0EA5E9),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CloudDriveScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _attachOption(
                      icon: Icons.schedule_send_rounded,
                      label: 'Schedule',
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        Navigator.pop(context);
                        _showSchedulePicker(context);
                      },
                    ),
                    _attachOption(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.pop(context);
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
                        Navigator.pop(context);
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
                    _attachOption(
                      icon: Icons.document_scanner_rounded,
                      label: 'Scan Doc',
                      color: const Color(0xFF10B981),
                      onTap: () async {
                        Navigator.pop(context);
                        final file = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          imageQuality: 90,
                        );
                        if (file != null && context.mounted) {
                          final scannedPath = await GoRouter.of(context)
                              .push<String>(
                                  '/ripple-doc-scanner?imagePath=${Uri.encodeComponent(file.path)}');
                          if (scannedPath != null) {
                            final scannedFile = File(scannedPath);
                            _sendMediaMessage(
                              scannedFile,
                              'file',
                              fileName:
                                  'Scan_${DateTime.now().millisecondsSinceEpoch}.png',
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 52), // spacer
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
    if (widget.isDecoy) {
      setState(() => _isSending = true);
      try {
        await _sendDecoyMessage(fileName ?? '[$type]', type: type, mediaUrl: file.path, fileName: fileName);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

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
        chatId: _chatId,
        text: fileName ?? '[$type]',
        type: type,
        mediaUrl: url,
        fileName: fileName,
        replyTo: _replyTo,
        isViewOnce: isViewOnce,
      );

      final myUid = ref.read(chatServiceProvider).myUid;
      await SocialService.checkAndUnlock(uid: myUid, trigger: 'image_sent');

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
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: _chatId,
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
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        chatId: _chatId,
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

  Future<void> _exportChat() async {
    setState(() => _isSending = true);
    try {
      final messagesSnap = await FirebaseService.firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .get();

      final buffer = StringBuffer();
      buffer.writeln('--------------------------------------------------');
      buffer.writeln('RIPPLE SECURE CHAT EXPORT');
      buffer.writeln('Chat ID: ${_chatId}');
      buffer.writeln('Partner: ${widget.partnerName}');
      buffer.writeln('Export Date: ${DateTime.now().toLocal()}');
      buffer.writeln('--------------------------------------------------\n');

      for (final doc in messagesSnap.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String? ?? 'Unknown';
        final text = data['text'] as String? ?? '';
        final type = data['type'] as String? ?? 'text';
        final createdAt = data['createdAt'] as Timestamp?;
        final timeStr = createdAt != null ? createdAt.toDate().toLocal().toString() : 'N/A';

        final senderLabel = senderId == ref.read(chatServiceProvider).myUid ? 'You' : widget.partnerName;
        final content = type == 'text' ? text : '[$type] ${data['mediaUrl'] ?? ''}';

        buffer.writeln('[$timeStr] $senderLabel: $content');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Ripple_Chat_${widget.partnerName.replaceAll(' ', '_')}.txt');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Exported chat with ${widget.partnerName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export chat: $e'),
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
              if (widget.isDecoy) {
                await _sendDecoyMessage('', type: 'gif', mediaUrl: gifUrl);
                return;
              }
              setState(() => _isSending = true);
              try {
                final chatService = ref.read(chatServiceProvider);
                await chatService.sendMessage(
                  chatId: _chatId,
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
          if (widget.isDecoy) {
            await _sendDecoyMessage(stickerEmoji, type: 'sticker');
            return;
          }
          setState(() => _isSending = true);
          try {
            final chatService = ref.read(chatServiceProvider);
            await chatService.sendMessage(
              chatId: _chatId,
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

  Future<void> _summarizeConversation() async {
    setState(() => _isSummarizing = true);
    AppHaptics.mediumTap();

    try {
      final messagesSnap =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatId)
              .collection('messages')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final messageList =
          messagesSnap.docs.reversed
              .map(
                (d) => {
                  'sender':
                      d.data()['senderId'] ==
                              ref.read(chatServiceProvider).myUid
                          ? 'Me'
                          : widget.partnerName,
                  'text': d.data()['text'] as String? ?? '',
                },
              )
              .where((m) => (m['text'] as String).isNotEmpty)
              .toList();

      if (messageList.isEmpty) {
        throw 'No messages to summarize';
      }

      final summary = await AiService.summariseChat(
        messages: messageList,
        chatName: widget.partnerName,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (_) => Dialog(
                backgroundColor: const Color(0xFF0A1628),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Text(
                            'Conversation Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            summary,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Summarization failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
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
      final myUid = ref.read(chatServiceProvider).myUid;
      final poll = PollModel(
        question: question,
        options: options,
        votes: {for (var i = 0; i < options.length; i++) i.toString(): []},
        createdAt: Timestamp.now(),
        creatorId: myUid,
      );

      final pollRef = await FirebaseService.firestore
          .collection('polls')
          .add(poll.toMap());

      await FirebaseService.chatsCollection
          .doc(_chatId)
          .collection('messages')
          .add({
            'senderId': myUid,
            'type': 'poll',
            'text': question,
            'mediaUrl': pollRef.id, // Use mediaUrl for pollId
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

      await FirebaseService.chatsCollection.doc(_chatId).update({
        'lastMessage': '📊 Poll: $question',
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

      await FirebaseService.chatsCollection
          .doc(_chatId)
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
      await FirebaseService.chatsCollection.doc(_chatId).update({
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
    if (widget.isDecoy) {
      setState(() => _isSending = true);
      try {
        await _sendDecoyMessage('🎙️ Voice message (${duration.inSeconds}s)', type: 'voice', mediaUrl: filePath);
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    setState(() => _isSending = true);
    try {
      final file = File(filePath);
      
      final isSteg = await PrivacyService.isSteganographyEnabled();
      File finalFile = file;
      bool hasSteg = false;
      
      if (isSteg) {
        final voiceBytes = await file.readAsBytes();
        final payloadBase64 = base64.encode(voiceBytes);
        final coverWavBytes = SteganographyService.generateRainfallWav(
          ((payloadBase64.length * 8) / 16000).ceil() + 2
        );
        final stegoBytes = await SteganographyService.encode(
          coverWavBytes: coverWavBytes,
          payload: payloadBase64,
        );
        final tempDir = await getTemporaryDirectory();
        final stegoFile = File('${tempDir.path}/stego_voice_${DateTime.now().millisecondsSinceEpoch}.wav');
        await stegoFile.writeAsBytes(stegoBytes);
        finalFile = stegoFile;
        hasSteg = true;
      }

      // Upload to Cloudinary as raw/auto
      final url = await CloudinaryService.uploadVideo(finalFile);
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
          .doc(_chatId)
          .collection('messages')
          .add({
            'senderId': chatService.myUid,
            'type': 'voice',
            'mediaUrl': url,
            'duration': duration.inSeconds,
            'waveformData': waveformData,
            'text': hasSteg ? 'Acoustic Steganography Active' : null,
            'steganography': hasSteg,
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
      await FirebaseService.chatsCollection.doc(_chatId).update({
        'lastMessage': '🎙️ Voice message',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      final myUid = ref.read(chatServiceProvider).myUid;
      await SocialService.checkAndUnlock(uid: myUid, trigger: 'voice_sent');

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
          thumbUrl = await CloudinaryService.uploadImage(File(thumbnailPath));
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
          .doc(_chatId)
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
            'isViewOnce': isViewOnce,
            'viewedBy': [],
          });

      await FirebaseService.chatsCollection.doc(_chatId).update({
        'lastMessage': isViewOnce ? '🎬 View Once Video' : '🎬 Video',
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

      final history =
          messages
              .take(8)
              .toList()
              .reversed
              .map(
                (m) => <String, String>{
                  'role': m.senderId == currentUid ? 'user' : 'other',
                  'text': m.text ?? '',
                },
              )
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
            .doc(_chatId)
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

  void _showUpgradeRequiredDialog(BuildContext context, {required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/plans');
            },
            child: const Text('Upgrade Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChatSummary() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.aquaCore),
                  SizedBox(height: 16),
                  Text(
                    'Summarising chat...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      final currentUid = ref.read(chatServiceProvider).myUid;
      final myName = ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

      final snap =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(_chatId)
              .collection('messages')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final messages =
          snap.docs.reversed
              .map(
                (d) => <String, String>{
                  'sender':
                      d.data()['senderId'] == currentUid
                          ? myName
                          : widget.partnerName,
                  'text': d.data()['text'] as String? ?? '',
                },
              )
              .where((m) => m['text']!.isNotEmpty)
              .toList();

      final summary = await AiService.summariseChat(
        messages: messages,
        chatName: widget.partnerName,
      );

      await SocialService.checkAndUnlock(uid: currentUid, trigger: 'ai_used');

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (_) => Dialog(
                backgroundColor: const Color(0xFF0A1628),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📋', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Text(
                            'Chat Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            summary,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: summary));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Summary copied!')),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 14,
                              color: AppColors.aquaCore,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Copy Summary',
                              style: TextStyle(color: AppColors.aquaCore),
                            ),
                          ],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Summary failed: $e')));
      }
    }
  }

  void _showTranslator(MessageModel message) {
    String? translation;
    bool isLoading = false;
    String selectedLang = 'English';

    final languages = [
      'English',
      'Hindi',
      'Telugu',
      'Tamil',
      'Spanish',
      'French',
      'German',
      'Japanese',
      'Korean',
      'Arabic',
      'Portuguese',
      'Italian',
      'Russian',
      'Chinese',
      'Turkish',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => StatefulBuilder(
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
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text('🌍', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'Translate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message.text ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          languages
                              .map(
                                (lang) => GestureDetector(
                                  onTap: () => translate(lang),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color:
                                          selectedLang == lang
                                              ? AppColors.aquaCore.withValues(
                                                alpha: 0.15,
                                              )
                                              : Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                      border: Border.all(
                                        color:
                                            selectedLang == lang
                                                ? AppColors.aquaCore
                                                : Colors.white24,
                                      ),
                                    ),
                                    child: Text(
                                      lang,
                                      style: TextStyle(
                                        color:
                                            selectedLang == lang
                                                ? AppColors.aquaCore
                                                : Colors.white60,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              )
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
                            borderRadius: BorderRadius.circular(10),
                          ),
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
                            color: AppColors.aquaCore.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🌍 $selectedLang',
                              style: TextStyle(
                                color: AppColors.aquaCore,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              translation!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => StatefulBuilder(
            builder: (bCtx, setModal) {
              Future<void> applyTone(String tone) async {
                setModal(() {
                  isLoading = true;
                  selectedTone = tone;
                });
                try {
                  final result = await AiService.fixTone(
                    text: originalText,
                    tone: tone,
                  );

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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text('✨', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'AI Tone Fixer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        originalText,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _toneChip(
                          '💼',
                          'Formal',
                          'formal',
                          selectedTone,
                          isLoading,
                          () => applyTone('formal'),
                        ),
                        _toneChip(
                          '😊',
                          'Friendly',
                          'friendly',
                          selectedTone,
                          isLoading,
                          () => applyTone('friendly'),
                        ),
                        _toneChip(
                          '😂',
                          'Funny',
                          'funny',
                          selectedTone,
                          isLoading,
                          () => applyTone('funny'),
                        ),
                        _toneChip(
                          '✂️',
                          'Shorter',
                          'shorter',
                          selectedTone,
                          isLoading,
                          () => applyTone('shorter'),
                        ),
                        _toneChip(
                          '📝',
                          'Longer',
                          'longer',
                          selectedTone,
                          isLoading,
                          () => applyTone('longer'),
                        ),
                        _toneChip(
                          '✅',
                          'Fix Grammar',
                          'grammar',
                          selectedTone,
                          isLoading,
                          () => applyTone('grammar'),
                        ),
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
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    else if (rewrittenText.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.aquaCore.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.aquaCore.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '✨ Rewritten',
                              style: TextStyle(
                                color: AppColors.aquaCore,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rewrittenText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _messageController.text = rewrittenText;
                          _messageController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: rewrittenText.length),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.aquaCore,
                          minimumSize: const Size(double.infinity, 48),
                        ),
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

  Widget _toneChip(
    String emoji,
    String label,
    String tone,
    String? selectedTone,
    bool isLoading,
    VoidCallback onTap,
  ) {
    final isSelected = selectedTone == tone;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              isSelected
                  ? AppColors.aquaCore.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? AppColors.aquaCore : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            (isLoading && isSelected)
                ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.aquaCore,
                  ),
                )
                : Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.aquaCore : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => StatefulBuilder(
            builder: (bCtx, setModal) {
              Future<void> compose(String instruction) async {
                setModal(() => isLoading = true);
                try {
                  final currentUid = ref.read(chatServiceProvider).myUid;
                  final myName =
                      ref.read(currentUserProvider).valueOrNull?.name ?? 'Me';

                  final snap =
                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(_chatId)
                          .collection('messages')
                          .orderBy('createdAt', descending: true)
                          .limit(10)
                          .get();

                  final history =
                      snap.docs.reversed
                          .map(
                            (d) => {
                              'role':
                                  d.data()['senderId'] == currentUid
                                      ? 'user'
                                      : 'other',
                              'text': d.data()['text'] as String? ?? '',
                            },
                          )
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
                  20,
                  16,
                  20,
                  MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Text('🤖', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text(
                          'AI Compose',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Describe what you want to say',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          suggestions
                              .map(
                                (s) => GestureDetector(
                                  onTap: () {
                                    instructionController.text = s;
                                    compose(s);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
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
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final instruction =
                                instructionController.text.trim();
                            if (instruction.isNotEmpty) compose(instruction);
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.aquaCore,
                              shape: BoxShape.circle,
                            ),
                            child:
                                isLoading
                                    ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (composed != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.aquaCore.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.aquaCore.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          composed!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          _messageController.text = composed!;
                          _messageController
                              .selection = TextSelection.fromPosition(
                            TextPosition(offset: composed!.length),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.aquaCore,
                          minimumSize: const Size(double.infinity, 48),
                        ),
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
      builder:
          (_) => Dialog(
            backgroundColor: const Color(0xFF0A1628),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.aquaCore),
                  SizedBox(height: 16),
                  Text(
                    'Analysing message...',
                    style: TextStyle(color: Colors.white),
                  ),
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
          builder:
              (_) => Dialog(
                backgroundColor: const Color(0xFF0A1628),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          const Text(
                            'Message Explained',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '"${message.text}"',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.35,
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            explanation,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not explain: $e')));
      }
    }
  }

  // ─── Chronos Messaging\u2122 Composer ─────────────────────────
  void _showChronosComposer(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChronosComposerSheet(
        onConditionSet: (type, value) {
          setState(() {
            _chronosConditionType = type;
            _chronosConditionValue = value;
          });
        },
      ),
    );
  }

  // ─── Schedule Message Picker ─────────────────────────────
  void _showSchedulePicker(BuildContext ctx) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    DateTime selectedDate = DateTime.now().add(const Duration(minutes: 5));

    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_send, color: AppColors.aquaCore),
                    const SizedBox(width: 12),
                    const Text(
                      'Schedule Message',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"$text"',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Send at:',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                // Quick time options
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TimeChip(
                      label: '5 min',
                      onTap: () => setModalState(() =>
                          selectedDate = DateTime.now().add(const Duration(minutes: 5))),
                    ),
                    _TimeChip(
                      label: '30 min',
                      onTap: () => setModalState(() =>
                          selectedDate = DateTime.now().add(const Duration(minutes: 30))),
                    ),
                    _TimeChip(
                      label: '1 hour',
                      onTap: () => setModalState(() =>
                          selectedDate = DateTime.now().add(const Duration(hours: 1))),
                    ),
                    _TimeChip(
                      label: 'Tomorrow 9AM',
                      onTap: () {
                        final tomorrow = DateTime.now().add(const Duration(days: 1));
                        setModalState(() => selectedDate = DateTime(
                            tomorrow.year, tomorrow.month, tomorrow.day, 9, 0));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Selected time display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.aquaCore.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColors.aquaCore),
                      const SizedBox(width: 12),
                      Text(
                        '${selectedDate.day}/${selectedDate.month} at ${selectedDate.hour}:${selectedDate.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await ScheduleService.scheduleMessage(
                        chatId: _chatId,
                        isGroup: false,
                        text: text,
                        sendAt: selectedDate,
                      );
                      _messageController.clear();
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Message scheduled successfully!'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.aquaCore,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Schedule Message'),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendDecoyMessage(String text, {String type = 'text', String? mediaUrl, String? fileName}) async {
    final myUid = ref.read(chatServiceProvider).myUid;
    final newMsg = MessageModel(
      id: 'decoy_msg_${const Uuid().v4()}',
      senderId: myUid,
      text: text.isNotEmpty ? text : null,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      createdAt: DateTime.now(),
      seenBy: [myUid],
    );
    setState(() {
      _decoyMessages.add(newMsg);
    });
    _scrollToBottom();

    // Auto mock reply
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final replyText = type == 'text' ? _generateMockReply(text) : 'That looks cool!';
      final replyMsg = MessageModel(
        id: 'decoy_msg_${const Uuid().v4()}',
        senderId: widget.partnerUid,
        text: replyText,
        type: 'text',
        createdAt: DateTime.now(),
        seenBy: [myUid],
      );
      setState(() {
        _decoyMessages.add(replyMsg);
      });
      _scrollToBottom();
    });
  }

  String _generateMockReply(String userMessage) {
    final lower = userMessage.toLowerCase();
    if (lower.contains('hello') || lower.contains('hi') || lower.contains('hey')) {
      return 'Hey there! How is your day going?';
    } else if (lower.contains('work') || lower.contains('project') || lower.contains('task')) {
      return 'Yeah, let\'s sync up on that tomorrow. I have the files ready.';
    } else if (lower.contains('dinner') || lower.contains('eat') || lower.contains('food')) {
      return 'Sounds good! I\'ll grab something in a bit.';
    } else if (lower.contains('gym') || lower.contains('workout') || lower.contains('exercise')) {
      return 'Count me in for tomorrow morning!';
    } else {
      final responses = [
        'Awesome, talk to you in a bit!',
        'Interesting, let me check and get back to you.',
        'Sounds good!',
        'No problem, take your time.',
        'Okay, let know if you need anything else.',
      ];
      return responses[math.Random().nextInt(responses.length)];
    }
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      label: Text(label),
      backgroundColor: Colors.white10,
      labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
      side: const BorderSide(color: Colors.white24),
    );
  }
}
