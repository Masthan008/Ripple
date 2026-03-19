import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/utils/app_lifecycle_observer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_glass_navbar/navbar_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../status/screens/status_list_screen.dart';
import '../../status/services/status_service.dart';
import '../../calls/screens/incoming_call_screen.dart';
import '../../ai/widgets/ai_bot_picker.dart';
import '../services/chat_organisation_service.dart';
import '../../../core/services/privacy_service.dart';
import '../../../core/services/chat_lock_service.dart';

/// Home screen with Telegram-style RippleNavBar — glass design per PRD §4.3
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  AppLifecycleObserver? _lifecycleObserver;
  StreamSubscription? _incomingCallSub;

  final _tabs = const [
    _ChatsTab(),
    StatusListScreen(),
    _GroupsTab(),
    _CallsTab(),
    _AiTab(),
    _ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Wire up notification handlers + presence after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Setup notification tap navigation
      NotificationService.setupNotificationHandlers(context);
      // Sync OneSignal player ID to Firestore for push notifications
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        // Immediate attempt
        NotificationService.syncPlayerId(uid);
        // Backup attempt after 10s in case OneSignal hasn't registered yet
        Future.delayed(
          const Duration(seconds: 10),
          () => NotificationService.syncPlayerId(uid),
        );

        // Initialize real-time presence (RTDB + Firestore sync)
        PresenceService.initialize(uid);

        // Register lifecycle observer for foreground/background status
        _lifecycleObserver = AppLifecycleObserver(uid);
        WidgetsBinding.instance.addObserver(_lifecycleObserver!);

        // Cleanup expired statuses & moods in background
        StatusService.cleanupExpired();
        StatusService.clearExpiredMood();

        // Listen for incoming calls (foreground detection)
        _listenForIncomingCalls(uid);
      }
    });
  }

  @override
  void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    _incomingCallSub?.cancel();
    super.dispose();
  }

  /// Listen for incoming call documents in Firestore.
  /// When a call doc has calleeId == myUid and status == 'ringing',
  /// push the IncomingCallScreen.
  void _listenForIncomingCalls(String myUid) {
    bool isFirstSnapshot = true;
    _incomingCallSub = FirebaseService.firestore
        .collection('calls')
        .where('calleeId', isEqualTo: myUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      // Skip the initial snapshot to avoid showing old/stale calls
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          // Only show calls created in the last 30 seconds
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            final age = DateTime.now().difference(createdAt.toDate());
            if (age.inSeconds > 30) continue;
          }

          final callId = change.doc.id;
          final callerName = data['callerName'] as String? ?? 'Unknown';
          final callerUserId = data['callerId'] as String? ?? '';
          final callType = data['type'] as String? ?? 'audio';
          // Channel name is the chatId used when initiating the call
          final channelName = data['channelName'] as String? ?? callId;

          // Push incoming call screen
          if (mounted) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => IncomingCallScreen(
                callId: callId,
                channelName: channelName,
                callerName: callerName,
                callerUserId: callerUserId,
                isVideo: callType == 'video',
              ),
            ));
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      extendBody: true, // Need this so body can flow under navbar glass
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: myUid != null
          ? _buildNavBarWithUnread(myUid, currentUser?.photoUrl)
          : LiquidNavbarWidget(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
            ),
    );
  }

  Widget _buildNavBarWithUnread(String myUid, String? photoUrl) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.chatsCollection
          .where('participants', arrayContains: myUid)
          .snapshots()
          .handleError((_) {}),
      builder: (ctx, chatSnap) {
        int totalChatUnread = 0;
        if (chatSnap.hasData) {
          for (final doc in chatSnap.data!.docs) {
            final unreadRaw = doc.data()['unreadCount'];
            final unread = unreadRaw is Map<String, dynamic> ? unreadRaw : null;
            totalChatUnread += (unread?[myUid] as int?) ?? 0;
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.firestore
              .collection('groups')
              .where('members', arrayContains: myUid)
              .snapshots()
              .handleError((_) {}),
          builder: (ctx2, groupSnap) {
            int totalGroupUnread = 0;
            if (groupSnap.hasData) {
              for (final doc in groupSnap.data!.docs) {
                final unreadRaw = doc.data()['unreadCount'];
                final unread =
                    unreadRaw is Map<String, dynamic> ? unreadRaw : null;
                totalGroupUnread += (unread?[myUid] as int?) ?? 0;
              }
            }

            return LiquidNavbarWidget(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              unreadCounts: [totalChatUnread, 0, totalGroupUnread, 0, 0, 0],
              userPhotoUrl: photoUrl,
            );
          },
        );
      },
    );
  }
}

// ─── Tab Stubs (Phase 2+) ────────────────────────────────

class _ChatsTab extends ConsumerStatefulWidget {
  const _ChatsTab();

  @override
  ConsumerState<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<_ChatsTab> {
  String _filter = 'all'; // all | unread | groups

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action buttons
            Row(
              children: [
                Text(AppStrings.messages, style: AppTextStyles.heading),
                const Spacer(),
                _GlassIconButton(
                  icon: Icons.search_rounded,
                  onTap: () => GoRouter.of(context).push('/search'),
                ),
                const SizedBox(width: 8),
                _GlassIconButton(
                  icon: Icons.person_add_rounded,
                  onTap: () => GoRouter.of(context).push('/requests'),
                ),
                const SizedBox(width: 8),
                _GlassIconButton(
                  icon: Icons.explore_rounded,
                  onTap: () => GoRouter.of(context).push('/users'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Filter chips
            Row(
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Unread',
                    selected: _filter == 'unread',
                    onTap: () => setState(() => _filter = 'unread')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Groups',
                    selected: _filter == 'groups',
                    onTap: () => setState(() => _filter = 'groups')),
              ],
            ),
            const SizedBox(height: 12),

            // Chat list
            Expanded(
              child: currentUser == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseService.firestore
                          .collection('users')
                          .doc(currentUser.uid)
                          .snapshots(),
                      builder: (ctx, userSnap) {
                        final userData = userSnap.data?.data()
                                is Map<String, dynamic>
                            ? userSnap.data!.data() as Map<String, dynamic>
                            : <String, dynamic>{};
                        final pinnedIds = List<String>.from(
                            userData['pinnedChats'] as List? ?? []);
                        final archivedIds = List<String>.from(
                            userData['archivedChats'] as List? ?? []);
                        final mutedIds = List<String>.from(
                            userData['mutedChats'] as List? ?? []);

                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseService.chatsCollection
                              .where('participants',
                                  arrayContains: currentUser.uid)
                              .snapshots()
                              .handleError((_) {}),
                          builder: (ctx, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                      AppColors.aquaCore),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: AppColors.errorRed, size: 48),
                                    const SizedBox(height: 12),
                                    Text('Cannot load chats',
                                        style: AppTextStyles.body),
                                  ],
                                ),
                              );
                            }

                            var chats = snapshot.data?.docs ?? [];

                            // Filter out archived
                            chats = chats
                                .where((d) => !archivedIds.contains(d.id))
                                .toList();

                            // Apply filter
                            if (_filter == 'unread') {
                              chats = chats.where((d) {
                                final data = d.data();
                                final seenBy = List<String>.from(
                                    data['seenBy'] as List? ?? []);
                                return !seenBy.contains(currentUser.uid) &&
                                    data['lastMessage'] != null;
                              }).toList();
                            }

                            // Sort: pinned first
                            chats.sort((a, b) {
                              final aPin = pinnedIds.contains(a.id) ? 0 : 1;
                              final bPin = pinnedIds.contains(b.id) ? 0 : 1;
                              return aPin.compareTo(bPin);
                            });

                            return ListView.builder(
                              itemCount: chats.length +
                                  1 + // Saved Messages row
                                  (archivedIds.isNotEmpty ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                // First item: Saved Messages
                                if (i == 0) {
                                  return _savedMessagesTile(context);
                                }

                                // Last item: Archived row
                                if (archivedIds.isNotEmpty &&
                                    i == chats.length + 1) {
                                  return _archivedRow(
                                      context, archivedIds.length);
                                }

                                final chatIndex = i - 1;
                                if (chatIndex >= chats.length) {
                                  return const SizedBox.shrink();
                                }

                                final doc = chats[chatIndex];
                                final data = doc.data();
                                final chatId = doc.id;
                                final isPinned = pinnedIds.contains(chatId);
                                final isMuted = mutedIds.contains(chatId);
                                final participants = List<String>.from(
                                    data['participants'] ?? []);
                                final otherUid = participants.firstWhere(
                                  (id) => id != currentUser.uid,
                                  orElse: () => '',
                                );
                                if (otherUid.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return GestureDetector(
                                  onLongPress: () => _showChatContextMenu(
                                    context: context,
                                    chatId: chatId,
                                    isPinned: isPinned,
                                    isMuted: isMuted,
                                  ),
                                  child: Stack(
                                    children: [
                                      _ChatTile(
                                        chatId: chatId,
                                        otherUid: otherUid,
                                        lastMessage: data['lastMessage'] is Map<String, dynamic>
                                            ? data['lastMessage'] as Map<String, dynamic>
                                            : null,
                                        streak: data['streak'] as int? ?? 0,
                                        lastStreakDate: data['lastStreakDate'] as Timestamp?,
                                      ),
                                      if (isPinned)
                                        Positioned(
                                          top: 12,
                                          right: 8,
                                          child: Icon(
                                            Icons.push_pin_rounded,
                                            size: 14,
                                            color: AppColors.aquaCore,
                                          ),
                                        ),
                                      if (isMuted)
                                        Positioned(
                                          bottom: 12,
                                          right: 8,
                                          child: Icon(
                                            Icons.notifications_off_rounded,
                                            size: 12,
                                            color: Colors.white
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedMessagesTile(BuildContext context) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/saved-messages'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  AppColors.aquaCore,
                  Color(0xFF6366F1),
                ]),
              ),
              child: const Icon(Icons.bookmark_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saved Messages',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('Tap to view',
                    style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _archivedRow(BuildContext context, int count) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/archived-chats'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
              child: Icon(Icons.archive_rounded,
                  color: AppColors.aquaCore, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Archived',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('$count chat${count > 1 ? "s" : ""}',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showChatContextMenu({
    required BuildContext context,
    required String chatId,
    required bool isPinned,
    required bool isMuted,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(
              isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: AppColors.aquaCore,
            ),
            title: Text(isPinned ? 'Unpin' : 'Pin',
                style: const TextStyle(color: Colors.white)),
            onTap: () async {
              if (isPinned) {
                await ChatOrganisationService.unpinChat(chatId);
              } else {
                final error =
                    await ChatOrganisationService.pinChat(chatId);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.archive_rounded, color: AppColors.aquaCore),
            title: const Text('Archive',
                style: TextStyle(color: Colors.white)),
            onTap: () async {
              await ChatOrganisationService.archiveChat(chatId);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              isMuted
                  ? Icons.notifications_rounded
                  : Icons.notifications_off_rounded,
              color: AppColors.aquaCore,
            ),
            title: Text(isMuted ? 'Unmute' : 'Mute',
                style: const TextStyle(color: Colors.white)),
            onTap: () async {
              if (isMuted) {
                await ChatOrganisationService.unmuteChat(chatId);
              } else {
                await ChatOrganisationService.muteChat(chatId);
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

/// Filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? AppColors.aquaCore.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected ? AppColors.aquaCore : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.aquaCore : Colors.white54,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Interactive search bar for filtering chats by name
class _ChatSearchBar extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? chatsStream;
  final String currentUid;

  const _ChatSearchBar({
    required this.chatsStream,
    required this.currentUid,
  });

  @override
  State<_ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends State<_ChatSearchBar> {
  bool _isSearching = false;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _allChats = [];
  bool _hasSubscribed = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    final seenUids = <String>{};

    for (final chatDoc in _allChats) {
      final data = chatDoc.data();
      final participants =
          List<String>.from(data['participants'] ?? []);
      final otherUid = participants.firstWhere(
        (id) => id != widget.currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty || seenUids.contains(otherUid)) continue;

      // Fetch partner name
      try {
        final userDoc = await FirebaseService.usersCollection
            .doc(otherUid)
            .get();
        final name =
            (userDoc.data()?['name'] as String? ?? '').toLowerCase();
        if (name.contains(lowerQuery)) {
          seenUids.add(otherUid);
          results.add({
            'chatId': chatDoc.id,
            'otherUid': otherUid,
            'name': userDoc.data()?['name'] ?? 'User',
            'photoUrl': userDoc.data()?['photoUrl'] ?? '',
          });
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _searchResults = results);
  }

  void _subscribeToChats() {
    if (_hasSubscribed || widget.chatsStream == null) return;
    _hasSubscribed = true;
    widget.chatsStream!.listen((snapshot) {
      _allChats = snapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe once to populate _allChats for search
    _subscribeToChats();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _isSearching = !_isSearching);
            if (_isSearching) {
              _focusNode.requestFocus();
            } else {
              _controller.clear();
              _searchResults = [];
              _focusNode.unfocus();
            }
          },
          child: Container(
            height: 44,
            decoration: GlassTheme.inputDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _isSearching
                ? Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.aquaCore, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onSearchChanged,
                          style: AppTextStyles.body
                              .copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search by name...',
                            hintStyle: AppTextStyles.caption
                                .copyWith(color: AppColors.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSearching = false;
                            _controller.clear();
                            _searchResults = [];
                          });
                          _focusNode.unfocus();
                        },
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textMuted, size: 18),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          color: AppColors.textMuted, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Search messages...',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
          ),
        ),
        // Search results
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.glassPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              itemBuilder: (ctx, i) {
                final result = _searchResults[i];
                return ListTile(
                  dense: true,
                  leading: AquaAvatar(
                    imageUrl: result['photoUrl'],
                    name: result['name'],
                    size: 32,
                  ),
                  title: Text(
                    result['name'],
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                  ),
                  onTap: () {
                    setState(() {
                      _isSearching = false;
                      _controller.clear();
                      _searchResults = [];
                    });
                    GoRouter.of(context).push(
                      '/chat?chatId=${result['chatId']}'
                      '&partnerUid=${result['otherUid']}'
                      '&partnerName=${Uri.encodeComponent(result['name'])}',
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Small frosted glass icon button for header actions
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.glassPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Icon(icon, color: AppColors.lightWave, size: 18),
      ),
    );
  }
}

/// Chat tile that fetches partner info and displays last message
class _ChatTile extends ConsumerWidget {
  final String chatId;
  final String otherUid;
  final Map<String, dynamic>? lastMessage;
  final int streak;
  final Timestamp? lastStreakDate;

  const _ChatTile({
    required this.chatId,
    required this.otherUid,
    this.lastMessage,
    this.streak = 0,
    this.lastStreakDate,
  });

  bool _isStreakActive() {
    if (lastStreakDate == null) return false;
    final lastDate = lastStreakDate!.toDate();
    final today = DateTime.now();
    final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final diff = todayOnly.difference(lastDateOnly).inDays;
    return diff <= 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseService.usersCollection.doc(otherUid).get(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snap.data!.data()!;
        final name = userData['name'] ?? 'User';
        final photoUrl = userData['photoUrl'] ?? '';
        final isOnlineRaw = userData['isOnline'] ?? false;

        // Privacy: check if we can see online status
        final currentUser = ref.read(currentUserProvider).valueOrNull;
        final myUid = currentUser?.uid ?? '';
        final myFriends = List<String>.from(currentUser?.friends ?? []);
        
        final isOnline = isOnlineRaw && PrivacyService.canSeeOnlineStatus(
          targetUser: userData,
          viewerUid: myUid,
          viewerFriends: myFriends,
        );

        // Determine preview text
        String preview;
        String timeStr = '';
        if (lastMessage != null && lastMessage!['text'] != null) {
          preview = lastMessage!['text'] ?? '';
          final ts = lastMessage!['timestamp'];
          if (ts is Timestamp) {
            timeStr = _formatTime(ts.toDate());
          }
        } else {
          preview = 'Say hello! 👋';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: InkWell(
              onLongPress: () async {
                final isLocked = await PrivacyService.isChatLocked(chatId);
                if (isLocked) {
                  final auth = await ChatLockService.authenticate(
                      reason: 'Unlock this chat');
                  if (auth) {
                    await PrivacyService.unlockChatLock(chatId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🔓 Chat unlocked')));
                    }
                  }
                } else {
                  await PrivacyService.lockChat(chatId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🔒 Chat locked')));
                  }
                }
                // The parent will rebuild on next stream tick
              },
              onTap: () async {
                final isLocked = await PrivacyService.isChatLocked(chatId);
                if (isLocked) {
                  final auth = await ChatLockService.authenticate(
                      reason: 'Unlock $name');
                  if (!auth) return;
                }

                if (context.mounted) {
                  GoRouter.of(context).push(
                    '/chat?chatId=$chatId&partnerUid=$otherUid&partnerName=${Uri.encodeComponent(name)}&partnerPhoto=${Uri.encodeComponent(photoUrl)}',
                  );
                }
              },
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      Hero(
                        tag: 'chat_avatar_$chatId',
                        child: AquaAvatar(
                          imageUrl: photoUrl.isNotEmpty ? photoUrl : null,
                          name: name,
                          size: 44,
                        ),
                      ),
                      if (isOnline)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.onlineGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.abyssBackground,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Chat title, typing, last message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Lock Icon
                            FutureBuilder<bool>(
                              future: PrivacyService.isChatLocked(chatId),
                              builder: (ctx, lockSnap) {
                                if (lockSnap.data == true) {
                                  return const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.lock_rounded, 
                                      size: 14, color: AppColors.aquaCore),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: lastMessage == null
                                ? AppColors.textMuted
                                : AppColors.textMuted,
                            fontStyle: lastMessage == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (timeStr.isNotEmpty)
                        Text(timeStr,
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 10)),
                      if (streak > 0 && _isStreakActive()) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 2),
                              Text(streak.toString(), 
                                style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat.jm().format(dt);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat.MMMd().format(dt);
    }
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppStrings.groups, style: AppTextStyles.heading),
                const Spacer(),
                _GlassIconButton(
                  icon: Icons.group_add_rounded,
                  onTap: () => GoRouter.of(context).push('/create-group'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: groups.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.caption),
                ),
                data: (groupList) {
                  if (groupList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined,
                              color: AppColors.aquaCore.withValues(alpha: 0.3),
                              size: 64),
                          const SizedBox(height: 12),
                          Text('No groups yet', style: AppTextStyles.bodySmall),
                          const SizedBox(height: 4),
                          Text('Tap + to create a group',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: groupList.length,
                    itemBuilder: (_, i) {
                      final group = groupList[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () =>
                              GoRouter.of(context).push('/group-chat?groupId=${group.id}&groupName=${Uri.encodeComponent(group.name)}'),
                          child: GlassCard(
                            borderRadius: 14,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                AquaAvatar(
                                  imageUrl: group.photoUrl,
                                  name: group.name,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(group.name,
                                          style: AppTextStyles.headingSmall
                                              .copyWith(fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('${group.memberCount} members',
                                          style: AppTextStyles.caption),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallsTab extends ConsumerWidget {
  const _CallsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.valueOrNull;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.calls, style: AppTextStyles.heading),
            const SizedBox(height: 16),
            Expanded(
              child: _CallsStreamBuilder(
                currentUid: currentUser.uid,
                buildCallList: (docs) => _buildCallList(docs, currentUser.uid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      String myUid) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final data = docs[i].data();
        final isOutgoing = data['callerId'] == myUid;
        final isVideo = data['type'] == 'video';
        final isGroup = data['isGroup'] == true;
        final status = data['status'] ?? 'ended';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Determine partner
        final partnerName = isGroup
            ? (data['groupName'] ?? 'Group Call')
            : (isOutgoing ? 'Outgoing Call' : 'Incoming Call');

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            borderRadius: 14,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Call type icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isVideo
                        ? AppColors.aquaCore.withValues(alpha: 0.12)
                        : AppColors.onlineGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: isVideo
                        ? AppColors.aquaCore
                        : AppColors.onlineGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partnerName,
                        style: AppTextStyles.body.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Icon(
                            isOutgoing
                                ? Icons.call_made_rounded
                                : Icons.call_received_rounded,
                            size: 12,
                            color: status == 'missed'
                                ? AppColors.errorRed
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status == 'missed'
                                ? 'Missed'
                                : isOutgoing
                                    ? 'Outgoing'
                                    : 'Incoming',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: status == 'missed'
                                  ? AppColors.errorRed
                                  : AppColors.textMuted,
                            ),
                          ),
                          if (createdAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              _formatCallTime(createdAt),
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Call back button
                GestureDetector(
                  onTap: () {
                    // TODO: Implement call back
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.glassPanel,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.glassBorder, width: 0.5),
                    ),
                    child: Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: AppColors.aquaCore,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCallTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(time);
  }
}

/// Merges three Firestore streams for calls (callerId, calleeId, memberIds)
/// to avoid PERMISSION_DENIED on non-existent 'participants' field.
/// Sorts client-side to avoid needing composite indexes.
class _CallsStreamBuilder extends StatelessWidget {
  final String currentUid;
  final Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>) buildCallList;

  const _CallsStreamBuilder({
    required this.currentUid,
    required this.buildCallList,
  });

  @override
  Widget build(BuildContext context) {
    // Stream 1: calls where user is the caller
    final callerStream = FirebaseService.firestore
        .collection('calls')
        .where('callerId', isEqualTo: currentUid)
        .limit(50)
        .snapshots()
        .handleError((_) {});

    // Stream 2: calls where user is the callee
    final calleeStream = FirebaseService.firestore
        .collection('calls')
        .where('calleeId', isEqualTo: currentUid)
        .limit(50)
        .snapshots()
        .handleError((_) {});

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: callerStream,
      builder: (ctx, callerSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: calleeStream,
          builder: (ctx, calleeSnap) {
            // Merge both streams
            final callerDocs = callerSnap.data?.docs ?? [];
            final calleeDocs = calleeSnap.data?.docs ?? [];

            // Deduplicate by doc ID
            final seen = <String>{};
            final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (final doc in [...callerDocs, ...calleeDocs]) {
              if (seen.add(doc.id)) allDocs.add(doc);
            }

            // Sort client-side by createdAt descending
            allDocs.sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            if (allDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.call_outlined,
                        color: AppColors.aquaCore.withValues(alpha: 0.3),
                        size: 64),
                    const SizedBox(height: 12),
                    Text('No call history', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text('Your calls will appear here',
                        style: AppTextStyles.caption),
                  ],
                ),
              );
            }

            return buildCallList(allDocs);
          },
        );
      },
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

class _AiTab extends StatelessWidget {
  const _AiTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AiBotPicker(),
    );
  }
}
