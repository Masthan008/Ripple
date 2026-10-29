import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/privacy_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/models/user_model.dart';
import '../../chat/providers/chat_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/services/social_service.dart';
import '../../chat/screens/chat_screen.dart';
import '../../chat/screens/video_player_screen.dart';
import '../../chat/models/message_model.dart';
import '../../gifts/screens/gift_cards_screen.dart';
import '../../../core/services/secret_chat_service.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../friends/providers/friends_provider.dart';
import '../../../core/services/notification_service.dart';

class OtherUserProfileScreen extends ConsumerStatefulWidget {
  final String uid;

  const OtherUserProfileScreen({super.key, required this.uid});

  @override
  ConsumerState<OtherUserProfileScreen> createState() =>
      _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState
    extends ConsumerState<OtherUserProfileScreen> {
  List<Map<String, dynamic>> _mutualFriends = [];
  String _currentTab = 'media'; // 'media' | 'links'
  bool _isSharingDisabled = false;

  @override
  void initState() {
    super.initState();
    _recordProfileVisit();
    _loadMutualFriends();
  }

  Future<void> _recordProfileVisit() async {
    try {
      final myUid = ref.read(chatServiceProvider).myUid;
      final me = ref.read(currentUserProvider).valueOrNull;

      if (me != null) {
        await SocialService.recordProfileVisit(
          profileOwnerId: widget.uid,
          visitorId: myUid,
          visitorName: me.name,
          visitorPhoto: me.photoUrl ?? '',
        );
      }
    } catch (e) {
      debugPrint('Error recording profile visit: $e');
    }
  }

  Future<void> _loadMutualFriends() async {
    try {
      final myUid = ref.read(chatServiceProvider).myUid;
      final friends = await SocialService.getMutualFriends(
        currentUid: myUid,
        targetUid: widget.uid,
      );
      if (mounted) setState(() => _mutualFriends = friends);
    } catch (e) {
      debugPrint('Error loading mutual friends: $e');
    }
  }

  // ─── Actions handlers ────────────────────────────────────

  void _showSelfDestructPicker(String chatId) {
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
                o['value'] == 0 ? Icons.timer_off_rounded : Icons.timer_rounded,
                color: AppColors.aquaCore,
              ),
              title: Text(
                o['label'] as String,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                await PrivacyService.setSelfDestructTimer(
                  chatId: chatId,
                  isGroup: false,
                  seconds: o['value'] as int,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Self-destruct timer set to ${o['label']}'),
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

  void _showQrCodeDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          borderRadius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Contact QR Code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: 'ripple://user/${widget.uid}',
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                user['name'] as String? ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (user['username'] != null)
                Text(
                  '@${user['username']}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.aquaCore,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editNickname(String currentNickname, String myUid) async {
    final controller = TextEditingController(text: currentNickname);
    final newNickname = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        title: const Text('Edit Contact Name', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter nickname',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.aquaCore),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save', style: TextStyle(color: AppColors.aquaCore)),
          ),
        ],
      ),
    );

    if (newNickname != null) {
      await FirebaseService.firestore
          .collection('users')
          .doc(myUid)
          .update({'nicknames.${widget.uid}': newNickname});
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _startSecretChat(String myUid) async {
    AppHaptics.mediumTap();
    try {
      final chatId = await SecretChatService.instance.createSecretChat(
        currentUid: myUid,
        partnerUid: widget.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Secret chat initialized! 🔒'),
            backgroundColor: AppColors.onlineGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start secret chat: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = ref.read(chatServiceProvider).myUid;
    final chatId = Helpers.getChatId(myUid, widget.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseService.usersCollection.doc(widget.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.abyssBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.aquaCore),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            backgroundColor: AppColors.abyssBackground,
            body: Center(
              child: Text('User not found', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final user = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final privacy = user['privacy'] as Map<String, dynamic>? ?? {};
        final rippleScore = user['rippleScore'] as int? ?? 0;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseService.firestore
              .collection('users')
              .doc(myUid)
              .snapshots(),
          builder: (context, myUserSnap) {
            final myUserData =
                myUserSnap.data?.data() as Map<String, dynamic>? ?? {};
            final blockedUsers =
                List<String>.from(myUserData['blockedUsers'] ?? []);
            final isBlocked = blockedUsers.contains(widget.uid);
            final myFriends = List<String>.from(myUserData['friends'] ?? []);

            final isOnline = PrivacyService.canSeeOnlineStatus(
              targetUser: user,
              viewerUid: myUid,
              viewerFriends: myFriends,
            );
            final canSeePhoto = PrivacyService.canSeeProfilePhoto(
              targetUser: user,
              viewerUid: myUid,
              viewerFriends: myFriends,
            );

            // Notifications / Mute state
            final mutedChats =
                Map<String, dynamic>.from(myUserData['mutedChats'] as Map? ?? {});
            bool isMuted = false;
            if (mutedChats.containsKey(chatId)) {
              final expiryStr = mutedChats[chatId] as String?;
              if (expiryStr == 'always') {
                isMuted = true;
              } else if (expiryStr != null) {
                final expiry = DateTime.tryParse(expiryStr);
                if (expiry != null && expiry.isAfter(DateTime.now())) {
                  isMuted = true;
                }
              }
            }

            // Local nickname support
            final nicknames =
                myUserData['nicknames'] as Map<String, dynamic>? ?? {};
            final customNickname = nicknames[widget.uid] as String?;
            final displayName = customNickname ?? (user['name'] as String? ?? 'User');

            return Scaffold(
              backgroundColor: AppColors.abyssBackground,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                    color: const Color(0xFF0C1E3A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) async {
                      if (val == 'auto_delete') {
                        _showSelfDestructPicker(chatId);
                      } else if (val == 'share_contact') {
                        Share.share(
                          'Contact Name: $displayName\nPhone: ${user['phone'] ?? 'N/A'}\nUsername: @${user['username'] ?? ''}',
                        );
                      } else if (val == 'block') {
                        if (isBlocked) {
                          await ref
                              .read(friendsServiceProvider)
                              .unblockUser(widget.uid);
                        } else {
                          await ref
                              .read(friendsServiceProvider)
                              .blockUser(widget.uid);
                        }
                      } else if (val == 'edit_contact') {
                        _editNickname(customNickname ?? '', myUid);
                      } else if (val == 'delete_contact') {
                        await ref
                            .read(friendsServiceProvider)
                            .unfriend(widget.uid);
                      } else if (val == 'send_gift') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GiftCardsScreen(),
                          ),
                        );
                      } else if (val == 'secret_chat') {
                        _startSecretChat(myUid);
                      } else if (val == 'disable_sharing') {
                        setState(() {
                          _isSharingDisabled = !_isSharingDisabled;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isSharingDisabled
                                  ? 'Profile info sharing disabled.'
                                  : 'Profile info sharing enabled.',
                            ),
                          ),
                        );
                      } else if (val == 'add_home') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Shortcut pinned to home screen!'),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'auto_delete',
                        child: Row(
                          children: [
                            Icon(Icons.timer_rounded,
                                color: AppColors.aquaCore, size: 20),
                            SizedBox(width: 12),
                            Text('Auto-Delete',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share_contact',
                        child: Row(
                          children: [
                            Icon(Icons.share_rounded,
                                color: AppColors.aquaCore, size: 20),
                            SizedBox(width: 12),
                            Text('Share contact',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(Icons.block_rounded,
                                color: isBlocked ? Colors.red : AppColors.aquaCore,
                                size: 20),
                            const SizedBox(width: 12),
                            Text(isBlocked ? 'Unblock user' : 'Block user',
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit_contact',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded,
                                color: AppColors.aquaCore, size: 20),
                            SizedBox(width: 12),
                            Text('Edit Contact',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete_contact',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                color: Colors.red, size: 20),
                            SizedBox(width: 12),
                            Text('Delete Contact',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'send_gift',
                        child: Row(
                          children: [
                            Icon(Icons.card_giftcard_rounded,
                                color: AppColors.aquaCore, size: 20),
                            SizedBox(width: 12),
                            Text('Send a Gift',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'secret_chat',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: AppColors.aquaCore, size: 20),
                            SizedBox(width: 12),
                            Text('Start Secret Chat',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'disable_sharing',
                        child: Row(
                          children: [
                            Icon(Icons.remove_circle_outline_rounded,
                                color: AppColors.aquaCore, size: 20),
                            const SizedBox(width: 12),
                            Text(
                                _isSharingDisabled
                                    ? 'Enable Sharing'
                                    : 'Disable Sharing',
                                style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'add_home',
                        child: Row(
                          children: [
                            Icon(Icons.add_to_home_screen_rounded,
                                color: AppColors.aquaCore, size: 20),
                            SizedBox(width: 12),
                            Text('Add to Home Screen',
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Centered Large Circle Avatar with glowing cyan shadow
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCyan.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: AquaAvatar(
                          imageUrl: canSeePhoto ? (user['photoUrl'] as String?) : null,
                          name: user['name'] as String? ?? 'User',
                          size: 110,
                          showOnlineDot: true,
                          isOnline: isOnline && (user['isOnline'] as bool? ?? false),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Centered Display Name and Subtitle status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: AppTextStyles.display.copyWith(fontSize: 26),
                          ),
                        ),
                        VerifiedBadge(
                          isVerified: user['isVerified'] as bool? ?? false,
                          userId: widget.uid,
                          size: 24,
                          padding: const EdgeInsets.only(left: 6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOnline && (user['isOnline'] as bool? ?? false)
                          ? 'online'
                          : 'last seen recently',
                      style: TextStyle(
                        color: isOnline && (user['isOnline'] as bool? ?? false)
                            ? AppColors.onlineGreen
                            : Colors.white38,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Row of 4 glass action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Message',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  chatId: chatId,
                                  partnerUid: widget.uid,
                                  partnerName: displayName,
                                  partnerPhoto: user['photoUrl'] as String?,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          icon: isMuted
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_rounded,
                          label: isMuted ? 'Unmute' : 'Mute',
                          onTap: () async {
                            if (isMuted) {
                              NotificationService.unmuteChat(chatId);
                            } else {
                              NotificationService.showMuteDialog(
                                  context, chatId);
                            }
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.call_rounded,
                          label: 'Call',
                          onTap: () {
                            // Start voice call
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Starting voice call...')),
                            );
                          },
                        ),
                        _buildActionButton(
                          icon: Icons.videocam_rounded,
                          label: 'Video',
                          onTap: () {
                            // Start video call
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Starting video call...')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Details card containing Phone & Username with QR sharing icon
                    GlassCard(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['phone'] as String? ?? 'Not Available',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Mobile',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: Colors.white12, height: 1),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['username'] != null
                                          ? '@${user['username']}'
                                          : 'No Username',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Username',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.qr_code_2_rounded,
                                  color: AppColors.aquaCore,
                                  size: 24,
                                ),
                                onPressed: () => _showQrCodeDialog(user),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Media / Links Tabs Header
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentTab = 'media'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentTab == 'media'
                                      ? AppColors.aquaCore.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'Media',
                                    style: TextStyle(
                                      color: _currentTab == 'media'
                                          ? AppColors.aquaCore
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentTab = 'links'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _currentTab == 'links'
                                      ? AppColors.aquaCore.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    'Links',
                                    style: TextStyle(
                                      color: _currentTab == 'links'
                                          ? AppColors.aquaCore
                                          : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid or List below Tabs
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseService.firestore
                          .collection('chats')
                          .doc(chatId)
                          .collection('messages')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, messagesSnap) {
                        if (!messagesSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.aquaCore),
                          );
                        }

                        final messages = messagesSnap.data!.docs
                            .map((d) => MessageModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
                            .where((m) =>
                                !m.isDeleted &&
                                !m.deletedFor.contains(myUid))
                            .toList();

                        if (_currentTab == 'media') {
                          final mediaMessages = messages
                              .where((m) =>
                                  m.type == 'image' ||
                                  m.type == 'video' ||
                                  m.type == 'gif')
                              .toList();

                          if (mediaMessages.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No shared media yet',
                                style: TextStyle(color: Colors.white38),
                              ),
                            );
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
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
                                        builder: (_) => VideoPlayerScreen(
                                            videoUrl: msg.mediaUrl ?? ''),
                                      ),
                                    );
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (_) => GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Container(
                                          color: Colors.black.withValues(alpha: 0.9),
                                          child: Center(
                                            child: Hero(
                                              tag: msg.id,
                                              child: InteractiveViewer(
                                                child: Image.network(
                                                  msg.mediaUrl ?? '',
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        msg.mediaUrl ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Container(
                                          color: Colors.white10,
                                          child: const Icon(Icons.broken_image,
                                              color: Colors.white38),
                                        ),
                                      ),
                                    ),
                                    if (msg.type == 'video')
                                      Center(
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black.withValues(alpha: 0.6),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        } else {
                          final linkMessages = messages
                              .where((m) =>
                                  m.type == 'text' &&
                                  m.text != null &&
                                  (m.text!.contains('http://') ||
                                      m.text!.contains('https://')))
                              .toList();

                          if (linkMessages.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No shared links yet',
                                style: TextStyle(color: Colors.white38),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: linkMessages.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, i) {
                              final msg = linkMessages[i];
                              // Simple URL parsing
                              final regExp = RegExp(
                                  r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+');
                              final match = regExp.firstMatch(msg.text ?? '');
                              final url = match != null ? match.group(0) : '';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.aquaCore.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.link_rounded,
                                      color: AppColors.aquaCore, size: 20),
                                ),
                                title: Text(
                                  url ?? 'Shared Link',
                                  style: const TextStyle(
                                      color: AppColors.aquaCore,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  msg.text ?? '',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () async {
                                  if (url != null && url.isNotEmpty) {
                                    final uri = Uri.parse(url.startsWith('http')
                                        ? url
                                        : 'https://$url');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  }
                                },
                              );
                            },
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 32),
        
                    const SizedBox(height: 24),
                    _buildMutualFriendsSection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.2,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMutualFriendsSection() {
    if (_mutualFriends.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'MUTUAL FRIENDS (${_mutualFriends.length})',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.aquaCore.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _mutualFriends.length,
              itemBuilder: (context, index) {
                final friend = _mutualFriends[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AquaAvatar(
                    imageUrl: friend['photoUrl'] as String?,
                    name: friend['name'] as String? ?? 'User',
                    size: 50,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
