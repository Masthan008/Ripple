import 'package:shimmer/shimmer.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/utils/app_lifecycle_observer.dart';
import '../../privacy/widgets/pin_entry_dialog.dart';
import '../../../core/services/decoy_provider.dart';
import '../../../core/services/decoy_matrix_generator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/animations.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/floating_particles.dart'; // Add this
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/liquid_pull_to_refresh.dart';
import '../../../shared/widgets/bioluminescent_glow.dart';
import '../../../shared/widgets/liquid_glass_navbar/navbar_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../status/screens/status_list_screen.dart';
import '../../status/screens/create_status_screen.dart';
import '../../status/screens/status_viewer_screen.dart';
import '../../status/services/status_service.dart';
import '../../status/models/status_model.dart';
import '../../ai/widgets/ai_bot_picker.dart';
import '../../profile/providers/settings_provider.dart'; // Add this
import '../services/chat_organisation_service.dart';
import '../services/schedule_service.dart';
import '../../../core/services/privacy_service.dart';
import '../../../core/services/chat_lock_service.dart';
import '../../../app.dart'; // Add this for routerProvider

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

        // Start scheduled message checker
        ScheduleService.startScheduleChecker();

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
    ScheduleService.stopScheduleChecker();
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
                GoRouter.of(context).push(
                  '/incoming-call?callId=$callId&channelName=$channelName&callerName=${Uri.encodeComponent(callerName)}&callerUserId=$callerUserId&isVideo=${callType == 'video'}',
                );
              }
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final currentTheme = ref.watch(themeProvider);
    final rippleTheme = ref.watch(rippleThemeProvider);

    return Scaffold(
      backgroundColor: rippleTheme.colors.background,
      extendBody: true, // Need this so body can flow under navbar glass
      body: Stack(
        children: [
          // Subtle floating particles background with theme color
          FloatingParticles(
            particleCount: 5,
            color: rippleTheme.colors.primary.withOpacity(
              currentTheme == 'light_glass' ? 0.3 : 0.8,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: IndexedStack(
              key: ValueKey<int>(_currentIndex),
              index: _currentIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          myUid != null
              ? _buildNavBarWithUnread(myUid, currentUser?.photoUrl)
              : LiquidNavbarWidget(
                currentIndex: _currentIndex,
                onTap: (i) {
                  AppHaptics.selectionTick();
                  setState(() => _currentIndex = i);
                },
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
            int unreadValue = 0;
            if (unreadRaw is Map<String, dynamic>) {
              unreadValue = (unreadRaw[myUid] as int?) ?? 0;
            } else if (unreadRaw is int) {
              unreadValue = unreadRaw;
            }
            totalChatUnread += unreadValue;
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
                int unreadValue = 0;
                if (unreadRaw is Map<String, dynamic>) {
                  unreadValue = (unreadRaw[myUid] as int?) ?? 0;
                } else if (unreadRaw is int) {
                  unreadValue = unreadRaw;
                }
                totalGroupUnread += unreadValue;
              }
            }

            return LiquidNavbarWidget(
              currentIndex: _currentIndex,
              onTap: (i) {
                AppHaptics.selectionTick();
                setState(() => _currentIndex = i);
              },
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
  String _filter = 'all'; // all | unread | groups | folderId
  
  // Folders stream and cached data
  Stream<QuerySnapshot<Map<String, dynamic>>>? _foldersStream;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _folders = [];

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser != null) {
      _foldersStream = FirebaseService.firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('folders')
          .orderBy('order')
          .snapshots();
    }
  }

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
                Text(L10n.s(ref, 'chats'), style: AppTextStyles.heading),
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

            // Status Stories Row
            _buildStatusStoriesRow(),
            const SizedBox(height: 12),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _FilterChip(
                    label: L10n.s(ref, 'all'),
                    selected: _filter == 'all',
                    onTap: () {
                      AppHaptics.selectionTick();
                      setState(() => _filter = 'all');
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: L10n.s(ref, 'unread'),
                    selected: _filter == 'unread',
                    onTap: () {
                      AppHaptics.selectionTick();
                      setState(() => _filter = 'unread');
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                  label: L10n.s(ref, 'groups'),
                  selected: _filter == 'groups',
                  onTap: () {
                    AppHaptics.selectionTick();
                    setState(() => _filter = 'groups');
                  },
                ),
                // Dynamic folder chips from stream
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _foldersStream,
                  builder: (context, foldersSnap) {
                    if (!foldersSnap.hasData || foldersSnap.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    // Cache folders for use in chat list filtering
                    _folders = foldersSnap.data!.docs;
                    
                    final folders = foldersSnap.data!.docs;
                    return Row(
                      children: folders.map((folder) {
                        final data = folder.data();
                        final folderId = folder.id;
                        final name = data['name'] as String? ?? 'Folder';
                        final isSelected = _filter == folderId;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: name,
                            selected: isSelected,
                            onTap: () {
                              AppHaptics.selectionTick();
                              setState(() => _filter = isSelected ? 'all' : folderId);
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                // Folder management button
                _FilterChip(
                  label: '+',
                  selected: false,
                  onTap: () => _showFolderManagement(context),
                ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Chat list
            Expanded(
              child: ref.watch(decoyModeProvider)
                  ? ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: DecoyMatrixGenerator.getDecoyChats().length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return _savedMessagesTile(context);
                        }
                        final chat = DecoyMatrixGenerator.getDecoyChats()[i - 1];
                        return _DecoyChatTile(
                          chatId: chat['id'] as String,
                          name: chat['partnerName'] as String,
                          preview: chat['lastMessage']['text'] as String,
                          unreadCount: chat['unreadCount'] as int,
                        );
                      },
                    )
                  : currentUser == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<DocumentSnapshot>(
                        stream:
                            FirebaseService.firestore
                                .collection('users')
                                .doc(currentUser.uid)
                                .snapshots(),
                        builder: (ctx, userSnap) {
                          final userData =
                              userSnap.data?.data() is Map<String, dynamic>
                                  ? userSnap.data!.data()
                                      as Map<String, dynamic>
                                  : <String, dynamic>{};
                          final pinnedIds = userData['pinnedChats'] is List
                              ? List<String>.from(userData['pinnedChats'] as List)
                              : <String>[];
                          final archivedIds = userData['archivedChats'] is List
                              ? List<String>.from(userData['archivedChats'] as List)
                              : <String>[];
                          final mutedIds = userData['mutedChats'] is List
                              ? List<String>.from(userData['mutedChats'] as List)
                              : <String>[];

                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: FirebaseService.chatsCollection
                                .where(
                                  'participants',
                                  arrayContains: currentUser.uid,
                                )
                                .snapshots()
                                .handleError((_) {}),
                            builder: (ctx, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const _ChatShimmer();
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: AppColors.errorRed,
                                        size: 48,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        L10n.s(ref, 'cannotLoadChats'),
                                        style: AppTextStyles.body,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              var chats = snapshot.data?.docs ?? [];

                              // Filter out archived
                              chats =
                                  chats
                                      .where((d) => !archivedIds.contains(d.id))
                                      .toList();

                              // Apply folder filters
                              if (_filter == 'groups') {
                                chats = chats.where((d) {
                                  final data = d.data();
                                  return data['isGroup'] == true;
                                }).toList();
                              } else if (_filter != 'all' && _filter != 'unread') {
                                // Filter is a folder ID - check if chat is in folder
                                final folderDoc = _folders.firstWhere(
                                  (d) => d.id == _filter,
                                  orElse: () => throw Exception('Folder not found'),
                                );
                                if (folderDoc != null && folderDoc.data() != null) {
                                  final folderData = folderDoc.data();
                                  final folderChatIds = folderData['chatIds'] is List
                                      ? List<String>.from(folderData['chatIds'] as List)
                                      : <String>[];
                                  final folderGroupIds = folderData['groupIds'] is List
                                      ? List<String>.from(folderData['groupIds'] as List)
                                      : <String>[];
                                  chats = chats.where((d) {
                                    final data = d.data();
                                    final isGroup = data['isGroup'] == true;
                                    if (isGroup) {
                                      return folderGroupIds.contains(d.id);
                                    } else {
                                      return folderChatIds.contains(d.id);
                                    }
                                  }).toList();
                                }
                              }

                              // Apply filter
                              if (_filter == 'unread') {
                                chats =
                                    chats.where((d) {
                                      final data = d.data();
                                      final seenBy = data['seenBy'] is List
                                          ? List<String>.from(data['seenBy'] as List)
                                          : <String>[];
                                      return !seenBy.contains(
                                            currentUser.uid,
                                          ) &&
                                          data['lastMessage'] != null;
                                    }).toList();
                              }

                              if (chats.isEmpty && archivedIds.isEmpty) {
                                return _buildEmptyState();
                              }

                              // Sort: pinned first
                              chats.sort((a, b) {
                                final aPin = pinnedIds.contains(a.id) ? 0 : 1;
                                final bPin = pinnedIds.contains(b.id) ? 0 : 1;
                                if (aPin != bPin) return aPin.compareTo(bPin);
                                
                                // Secondary sort by timestamp
                                final aLastMsg = a.data()['lastMessage'];
                                final bLastMsg = b.data()['lastMessage'];
                                final aTs = (aLastMsg is Map<String, dynamic> && aLastMsg['timestamp'] is Timestamp)
                                    ? (aLastMsg['timestamp'] as Timestamp).millisecondsSinceEpoch
                                    : 0;
                                final bTs = (bLastMsg is Map<String, dynamic> && bLastMsg['timestamp'] is Timestamp)
                                    ? (bLastMsg['timestamp'] as Timestamp).millisecondsSinceEpoch
                                    : 0;
                                return bTs.compareTo(aTs);
                              });

                              return LiquidPullToRefresh(
                                onRefresh: () async {
                                  AppHaptics.mediumTap();
                                  await Future.delayed(
                                    const Duration(seconds: 1),
                                  );
                                  // Invalidating the provider will trigger a re-fetch
                                  ref.invalidate(authStateProvider);
                                },
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  itemCount:
                                      chats.length +
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
                                        context,
                                        archivedIds.length,
                                      );
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
                                    final participants = data['participants'] is List
                                        ? List<String>.from(data['participants'] as List)
                                        : <String>[];
                                    final otherUid = participants.firstWhere(
                                      (id) => id != currentUser.uid,
                                      orElse: () => '',
                                    );
                                    if (otherUid.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    final unreadRaw = data['unreadCount'];
                                    int unreadCount = 0;
                                    if (unreadRaw is Map<String, dynamic>) {
                                      unreadCount = (unreadRaw[currentUser.uid] as int?) ?? 0;
                                    } else if (unreadRaw is int) {
                                      unreadCount = unreadRaw;
                                    }

                                    return GestureDetector(
                                      onLongPress:
                                          () => _showChatContextMenu(
                                            context: context,
                                            chatId: chatId,
                                            isPinned: isPinned,
                                            isMuted: isMuted,
                                          ),
                                      child: Stack(
                                        children: [
                                          _ChatTile(
                                            key: ValueKey('chat_tile_$chatId'),
                                            chatId: chatId,
                                            otherUid: otherUid,
                                            lastMessage:
                                                data['lastMessage']
                                                        is Map<String, dynamic>
                                                    ? data['lastMessage']
                                                        as Map<String, dynamic>
                                                    : null,
                                            streak: data['streak'] is int
                                                ? data['streak'] as int
                                                : (data['streak'] is String
                                                    ? int.tryParse(data['streak'] as String) ?? 0
                                                    : 0),
                                            lastStreakDate:
                                                data['lastStreakDate'] is Timestamp
                                                    ? data['lastStreakDate'] as Timestamp
                                                    : null,
                                            unreadCount: unreadCount,
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
                                                color: Colors.white.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
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
                gradient: LinearGradient(
                  colors: [AppColors.aquaCore, Color(0xFF6366F1)],
                ),
              ),
              child: const Icon(
                Icons.bookmark_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.s(ref, 'savedMessages'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  L10n.s(ref, 'tapToView'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
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
              child: const Icon(
                Icons.archive_rounded,
                color: AppColors.aquaCore,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.s(ref, 'archived'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$count ${L10n.s(ref, 'chats').toLowerCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
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
  }) async {
    final isLocked = await PrivacyService.isChatLocked(chatId);

    if (!context.mounted) return;

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
                title: Text(
                  isPinned ? L10n.s(ref, 'unpin') : L10n.s(ref, 'pin'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  if (isPinned) {
                    await ChatOrganisationService.unpinChat(chatId);
                  } else {
                    final error = await ChatOrganisationService.pinChat(chatId);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error)));
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.archive_rounded,
                  color: AppColors.aquaCore,
                ),
                title: Text(
                  L10n.s(ref, 'archived'),
                  style: const TextStyle(color: Colors.white),
                ),
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
                title: Text(
                  isMuted ? L10n.s(ref, 'unmute') : L10n.s(ref, 'mute'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  if (isMuted) {
                    await ChatOrganisationService.unmuteChat(chatId);
                  } else {
                    await ChatOrganisationService.muteChat(chatId);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: AppColors.aquaCore,
                ),
                title: Text(
                  isLocked
                      ? L10n.s(ref, 'unlockChat')
                      : L10n.s(ref, 'lockChat'),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  if (isLocked) {
                    final auth = await ChatLockService.authenticate(
                      reason: L10n.s(ref, 'unlockReason'),
                    );
                    if (auth) {
                      await PrivacyService.unlockChatLock(chatId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L10n.s(ref, 'chatUnlocked'))),
                        );
                      }
                    }
                  } else {
                    await PrivacyService.lockChat(chatId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(L10n.s(ref, 'chatLockedMsg'))),
                      );
                    }
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_open_rounded,
                  color: AppColors.aquaCore,
                ),
                title: const Text(
                  'Add to Folder',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAddToFolderPicker(context, chatId);
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Shimmer.fromColors(
            baseColor: AppColors.aquaCore.withValues(alpha: 0.1),
            highlightColor: AppColors.aquaCore.withValues(alpha: 0.3),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
                border: Border.all(color: AppColors.aquaCore, width: 2),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            L10n.s(ref, 'noChatsYet'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              L10n.s(ref, 'startChattingWithFriends'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => GoRouter.of(context).push('/users'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(L10n.s(ref, 'findFriends')),
          ),
        ],
      ),
    );
  }

  // ─── FOLDER MANAGEMENT ─────────────────────────────────

  void _showFolderManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FolderManagementSheet(
        folders: _folders,
        onCreateFolder: _createFolder,
        onDeleteFolder: _deleteFolder,
      ),
    );
  }

  Future<void> _createFolder(String name, String icon, String color) async {
    await ChatOrganisationService.createFolder(
      name: name,
      icon: icon,
      color: color,
      order: _folders.length,
    );
  }

  Future<void> _deleteFolder(String folderId) async {
    await ChatOrganisationService.deleteFolder(folderId);
  }

  void _showAddToFolderPicker(BuildContext context, String chatId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddToFolderSheet(
        folders: _folders,
        chatId: chatId,
        onAddToFolder: (folderId) async {
          await ChatOrganisationService.addChatToFolder(
            folderId: folderId,
            chatId: chatId,
          );
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Chat added to folder')),
            );
          }
        },
      ),
    );
  }

  // ─── STATUS SHEETS ────────────────────────────────────

  void _showCreateStatusSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CreateStatusSheet(),
    );
  }

  void _showStatusViewer(BuildContext context, String uid) async {
    final statuses = await StatusService.getUserStatuses(uid);
    if (!context.mounted || statuses.isEmpty) return;

    // Get user info
    final userDoc = await FirebaseService.firestore.collection('users').doc(uid).get();
    final userName = userDoc.data()?['displayName'] as String? ?? 'User';

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          statuses: statuses,
          viewerName: userName,
        ),
      ),
    );
  }

  // ─── STATUS STORIES ROW ─────────────────────────────────

  Widget _buildStatusStoriesRow() {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    if (currentUser == null) return const SizedBox.shrink();

    return SizedBox(
      height: 90,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseService.firestore
            .collection('statuses')
            .where('uid', isNotEqualTo: currentUser.uid)
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('expiresAt', descending: false)
            .snapshots(),
        builder: (context, statusSnap) {
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseService.firestore
                .collection('users')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final myStatus = userData?['currentStatus'];
              final hasMyStatus = myStatus != null && myStatus.isNotEmpty;

              // Get unique users with statuses
              final statusDocs = statusSnap.data?.docs ?? [];
              final userStatuses = <String, Map<String, dynamic>>{};
              for (final doc in statusDocs) {
                final data = doc.data();
                final uid = data['uid'] as String?;
                if (uid != null && !userStatuses.containsKey(uid)) {
                  userStatuses[uid] = data;
                }
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 1 + userStatuses.length, // My status + others
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // My Status
                    return _StatusBubble(
                      isMyStatus: true,
                      hasStatus: hasMyStatus,
                      photoUrl: userData?['photoUrl'] as String?,
                      name: 'My Status',
                      onTap: () {
                        if (hasMyStatus) {
                          _showStatusViewer(context, currentUser.uid);
                        } else {
                          _showCreateStatusSheet(context);
                        }
                      },
                    );
                  }

                  // Friend's status
                  final entry = userStatuses.entries.elementAt(index - 1);
                  final uid = entry.key;
                  final data = entry.value;

                  return _StatusBubble(
                    isMyStatus: false,
                    hasStatus: true,
                    photoUrl: data['photoUrl'] as String?,
                    name: data['name'] as String? ?? 'User',
                    onTap: () => _showStatusViewer(context, uid),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FolderManagementSheet extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> folders;
  final Function(String, String, String) onCreateFolder;
  final Function(String) onDeleteFolder;

  const _FolderManagementSheet({
    required this.folders,
    required this.onCreateFolder,
    required this.onDeleteFolder,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Chat Folders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (folders.isEmpty)
            const Center(
              child: Text(
                'No folders yet. Create your first folder!',
                style: TextStyle(color: Colors.white54),
              ),
            )
          else
            ...folders.map((folder) {
              final data = folder.data();
              final name = data['name'] as String? ?? 'Folder';
              return ListTile(
                leading: const Icon(Icons.folder_rounded, color: AppColors.aquaCore),
                title: Text(name, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await onDeleteFolder(folder.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              );
            }),
          const Divider(color: Colors.white24),
          TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'New folder name',
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.aquaCore),
                onPressed: () async {
                  if (nameController.text.isNotEmpty) {
                    await onCreateFolder(
                      nameController.text,
                      'folder',
                      '#0EA5E9',
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _AddToFolderSheet extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> folders;
  final String chatId;
  final Function(String) onAddToFolder;

  const _AddToFolderSheet({
    required this.folders,
    required this.chatId,
    required this.onAddToFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Add to Folder',
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
          if (folders.isEmpty)
            const Center(
              child: Text(
                'Create folders first to organize your chats',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...folders.map((folder) {
              final data = folder.data();
              final name = data['name'] as String? ?? 'Folder';
              return ListTile(
                leading: const Icon(Icons.folder_rounded, color: AppColors.aquaCore),
                title: Text(name, style: const TextStyle(color: Colors.white)),
                onTap: () => onAddToFolder(folder.id),
              );
            }),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

/// Status bubble widget for stories row
class _StatusBubble extends StatelessWidget {
  final bool isMyStatus;
  final bool hasStatus;
  final String? photoUrl;
  final String name;
  final VoidCallback onTap;

  const _StatusBubble({
    required this.isMyStatus,
    required this.hasStatus,
    required this.photoUrl,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with status ring
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStatus
                    ? LinearGradient(
                        colors: [AppColors.aquaCore, AppColors.aquaCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: hasStatus ? null : Colors.white10,
              ),
              padding: hasStatus ? const EdgeInsets.all(3) : null,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.abyssBackground,
                ),
                padding: const EdgeInsets.all(2),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white10,
                      backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(photoUrl!)
                          : null,
                      child: photoUrl == null || photoUrl!.isEmpty
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    // Add button for my status when empty
                    if (isMyStatus && !hasStatus)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.aquaCore,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.abyssBackground,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Name
            Text(
              isMyStatus ? 'My Status' : name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatShimmer extends StatelessWidget {
  const _ChatShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder:
          (ctx, i) => Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color:
              selected
                  ? AppColors.aquaCore.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color:
                selected
                    ? AppColors.aquaCore.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: AppColors.aquaCore.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ]
                  : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Interactive search bar for filtering chats by name
class _ChatSearchBar extends ConsumerStatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? chatsStream;
  final String currentUid;

  const _ChatSearchBar({required this.chatsStream, required this.currentUid});

  @override
  ConsumerState<_ChatSearchBar> createState() => _ChatSearchBarState();
}

class _ChatSearchBarState extends ConsumerState<_ChatSearchBar> {
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
      final participants = data['participants'] is List
          ? List<String>.from(data['participants'] as List)
          : <String>[];
      final otherUid = participants.firstWhere(
        (id) => id != widget.currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty || seenUids.contains(otherUid)) continue;

      // Fetch partner name
      try {
        final userDoc =
            await FirebaseService.usersCollection.doc(otherUid).get();
        final userData = userDoc.data();
        if (userData == null) continue;

        final name = (userData['name'] as String? ?? '').toLowerCase();
        if (name.contains(lowerQuery)) {
          seenUids.add(otherUid);

          // Check privacy for profile photo
          final currentUser = ref.read(currentUserProvider).valueOrNull;
          final myUid = currentUser?.uid ?? widget.currentUid;
          final myFriends = currentUser?.friends is List
              ? List<String>.from(currentUser!.friends as List)
              : <String>[];

          final canSeePhoto = PrivacyService.canSeeProfilePhoto(
            targetUser: userData,
            viewerUid: myUid,
            viewerFriends: myFriends,
          );

          results.add({
            'chatId': chatDoc.id,
            'otherUid': otherUid,
            'name': userData['name'] ?? 'User',
            'photoUrl': canSeePhoto ? (userData['photoUrl'] as String? ?? '') : '',
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            height: 48,
            decoration: BoxDecoration(
              color:
                  _isSearching
                      ? AppColors.glassPanel.withValues(alpha: 0.25)
                      : AppColors.glassPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    _isSearching
                        ? AppColors.aquaCore.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow:
                  _isSearching
                      ? [
                        BoxShadow(
                          color: AppColors.aquaCore.withValues(alpha: 0.1),
                          blurRadius: 15,
                          spreadRadius: -2,
                        ),
                      ]
                      : [],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child:
                _isSearching
                    ? Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.aquaCore,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: L10n.s(ref, 'searchByName'),
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            AppHaptics.lightTap();
                            setState(() {
                              _isSearching = false;
                              _controller.clear();
                              _searchResults = [];
                            });
                            _focusNode.unfocus();
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 20,
                          ),
                        ),
                      ],
                    )
                    : Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          L10n.s(ref, 'searchMessages'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 15,
                          ),
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
                      '&partnerName=${Uri.encodeComponent(result['name'])}'
                      '&partnerPhoto=${Uri.encodeComponent(result['photoUrl'])}',
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
      onTap: () {
        AppHaptics.lightTap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.glassPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.aquaCore.withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _DecoyChatTile extends ConsumerWidget {
  final String chatId;
  final String name;
  final String preview;
  final int unreadCount;

  const _DecoyChatTile({
    required this.chatId,
    required this.name,
    required this.preview,
    required this.unreadCount,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat.jm().format(DateTime.now().subtract(const Duration(minutes: 10)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          if (unreadCount > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.aquaCore.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: InkWell(
              onTap: () {
                GoRouter.of(context).push(
                  '/chat?chatId=$chatId&partnerUid=decoy_user_partner&partnerName=${Uri.encodeComponent(name)}&partnerPhoto=&isDecoy=true',
                );
              },
              child: Row(
                children: [
                  AquaAvatar(
                    imageUrl: null,
                    name: name,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
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
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
                      Text(
                        timeStr,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.aquaCore,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat tile that fetches partner info and displays last message
class _ChatTile extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUid;
  final Map<String, dynamic>? lastMessage;
  final int streak;
  final Timestamp? lastStreakDate;
  final int unreadCount;

  const _ChatTile({
    required this.chatId,
    required this.otherUid,
    this.lastMessage,
    this.streak = 0,
    this.lastStreakDate,
    this.unreadCount = 0,
    super.key,
  });

  @override
  ConsumerState<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends ConsumerState<_ChatTile> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = FirebaseService.usersCollection.doc(widget.otherUid).get();
  }

  @override
  void didUpdateWidget(covariant _ChatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.otherUid != widget.otherUid) {
      _userFuture = FirebaseService.usersCollection.doc(widget.otherUid).get();
    }
  }

  bool _isStreakActive() {
    if (widget.lastStreakDate == null) return false;
    final lastDate = widget.lastStreakDate!.toDate();
    final today = DateTime.now();
    final lastDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final diff = todayOnly.difference(lastDateOnly).inDays;
    return diff <= 1;
  }

  String _formatTime(WidgetRef ref, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat.jm().format(dt);
    } else if (diff.inDays == 1) {
      return L10n.s(ref, 'yesterday');
    } else {
      return DateFormat.MMMd().format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _userFuture,
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snap.data!.data()!;
        final name = userData['name'] ?? 'User';
        final photoUrlRaw = userData['photoUrl'] ?? '';
        final isOnlineRaw = userData['isOnline'] ?? false;

        // Privacy: check if we can see online status and profile photo
        final currentUser = ref.read(currentUserProvider).valueOrNull;
        final myUid = currentUser?.uid ?? '';
        final myFriends = currentUser?.friends is List
            ? List<String>.from(currentUser!.friends as List)
            : <String>[];

        final isOnline =
            isOnlineRaw &&
            PrivacyService.canSeeOnlineStatus(
              targetUser: userData,
              viewerUid: myUid,
              viewerFriends: myFriends,
            );

        final canSeePhoto = PrivacyService.canSeeProfilePhoto(
          targetUser: userData,
          viewerUid: myUid,
          viewerFriends: myFriends,
        );
        final photoUrl = canSeePhoto ? photoUrlRaw : '';

        // Determine preview text
        String preview;
        String timeStr = '';
        if (widget.lastMessage != null && widget.lastMessage is Map<String, dynamic>) {
          final lastMsg = widget.lastMessage as Map<String, dynamic>;
          preview = lastMsg['text'] as String? ?? '';
          final ts = lastMsg['timestamp'];
          if (ts is Timestamp) {
            timeStr = _formatTime(ref, ts.toDate());
          }
        } else {
          preview = L10n.s(ref, 'sayHello');
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              // Bioluminescent Glow for Unread Messages
              if (widget.unreadCount > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCore.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              GlassCard(
                borderRadius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: InkWell(
                  onTap: () async {
                    final isLocked = await PrivacyService.isChatLocked(
                      widget.chatId,
                    );
                    if (isLocked) {
                      final auth = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PinEntryDialog(
                          title: '${L10n.s(ref, "chatLocked")}: $name',
                        ),
                      );
                      if (auth != true) return;

                      // Fix: Unlock the chat once authenticated via tap
                      await PrivacyService.unlockChatLock(widget.chatId);
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L10n.s(ref, 'chatUnlocked'))),
                        );
                      }
                    }

                    // Increased delay to ensure biometric UI is fully dismissed
                    // and the app state is stable.
                    await Future.delayed(const Duration(milliseconds: 400));

                    if (context.mounted) {
                      // Use GoRouter.of(context) directly for most reliable context-based navigation
                      GoRouter.of(context).push(
                        '/chat?chatId=${widget.chatId}&partnerUid=${widget.otherUid}&partnerName=${Uri.encodeComponent(name)}&partnerPhoto=${Uri.encodeComponent(photoUrl)}',
                      );
                    } else {
                      // Fallback to global router if context is unmounted
                      ref.read(routerProvider).push(
                        '/chat?chatId=${widget.chatId}&partnerUid=${widget.otherUid}&partnerName=${Uri.encodeComponent(name)}&partnerPhoto=${Uri.encodeComponent(photoUrl)}',
                      );
                    }
                  },
                  child: Row(
                    children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      Hero(
                        tag: 'chat_avatar_${widget.chatId}',
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
                              future: PrivacyService.isChatLocked(
                                widget.chatId,
                              ),
                              builder: (ctx, lockSnap) {
                                if (lockSnap.data == true) {
                                  return const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: 14,
                                      color: AppColors.aquaCore,
                                    ),
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
                            color:
                                widget.lastMessage == null
                                    ? AppColors.textMuted
                                    : AppColors.textMuted,
                            fontStyle:
                                widget.lastMessage == null
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
                        Text(
                          timeStr,
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      if (widget.streak > 0 && _isStreakActive()) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🔥', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 2),
                              Text(
                                widget.streak.toString(),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
        ),
      );
    },
  );
}
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(decoyModeProvider)) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(L10n.s(ref, 'groups'), style: AppTextStyles.heading),
                  const Spacer(),
                  _GlassIconButton(
                    icon: Icons.group_add_rounded,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        color: AppColors.aquaCore.withValues(alpha: 0.3),
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        L10n.s(ref, 'noGroups') ?? 'No groups',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final groups = ref.watch(myGroupsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(L10n.s(ref, 'groups'), style: AppTextStyles.heading),
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
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                      ),
                    ),
                error:
                    (e, _) => Center(
                      child: Text('Error: $e', style: AppTextStyles.caption),
                    ),
                data: (groupList) {
                  if (groupList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.group_outlined,
                            color: AppColors.aquaCore.withValues(alpha: 0.3),
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            L10n.s(ref, 'noGroups'),
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            L10n.s(ref, 'tapToCreateGroup'),
                            style: AppTextStyles.caption,
                          ),
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
                          onTap:
                              () => GoRouter.of(context).push(
                                '/group-chat?groupId=${group.id}&groupName=${Uri.encodeComponent(group.name)}',
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: AppTextStyles.headingSmall
                                            .copyWith(fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${group.memberCount} ${L10n.s(ref, 'members')}',
                                        style: AppTextStyles.caption,
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
    if (ref.watch(decoyModeProvider)) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L10n.s(ref, 'calls'), style: AppTextStyles.heading),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.call_end_rounded,
                        color: AppColors.aquaCore.withValues(alpha: 0.2),
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(L10n.s(ref, 'noCallHistory') ?? 'No call history', style: AppTextStyles.body),
                      const SizedBox(height: 4),
                      Text(L10n.s(ref, 'callsAppearHere') ?? 'Calls appear here', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

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
            Text(L10n.s(ref, 'calls'), style: AppTextStyles.heading),
            const SizedBox(height: 16),
            Expanded(
              child: _CallsStreamBuilder(
                currentUid: currentUser.uid,
                buildCallList:
                    (docs) => _buildCallList(docs, currentUser.uid, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String myUid,
    WidgetRef ref,
  ) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_end_rounded,
              color: AppColors.aquaCore.withValues(alpha: 0.2),
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(L10n.s(ref, 'noCallHistory'), style: AppTextStyles.body),
            const SizedBox(height: 4),
            Text(L10n.s(ref, 'callsAppearHere'), style: AppTextStyles.caption),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final data = docs[i].data();
        final callerId = data['callerId'] as String?;
        final isOutgoing = callerId == myUid;
        final isVideo = data['type'] == 'video';
        final isGroup = data['isGroup'] == true;
        final status = data['status'] ?? 'ended';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Determine partner
        final partnerName =
            isGroup
                ? (data['groupName'] as String? ?? L10n.s(ref, 'groupCall'))
                : (isOutgoing
                    ? L10n.s(ref, 'outgoing')
                    : L10n.s(ref, 'incoming'));

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Call type icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color:
                        isVideo
                            ? AppColors.aquaCore.withValues(alpha: 0.12)
                            : AppColors.onlineGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: isVideo ? AppColors.aquaCore : AppColors.onlineGreen,
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
                            color:
                                status == 'missed'
                                    ? AppColors.errorRed
                                    : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status == 'missed'
                                ? L10n.s(ref, 'missed')
                                : isOutgoing
                                ? L10n.s(ref, 'outgoing')
                                : L10n.s(ref, 'incoming'),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color:
                                  status == 'missed'
                                      ? AppColors.errorRed
                                      : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (createdAt != null)
                  Text(
                    _formatCallTime(ref, createdAt),
                    style: AppTextStyles.caption.copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCallTime(WidgetRef ref, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat.jm().format(dt);
    } else if (diff.inDays == 1) {
      return L10n.s(ref, 'yesterday');
    } else {
      return DateFormat.MMMd().format(dt);
    }
  }
}

class _AiTab extends ConsumerWidget {
  const _AiTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.s(ref, 'ai'), style: AppTextStyles.heading.copyWith(
              color: theme.colors.textPrimary,
            )),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_rounded,
                      size: 80,
                      color: theme.colors.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      L10n.s(ref, 'aiAssistant'),
                      style: AppTextStyles.headingSmall.copyWith(
                        color: theme.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        L10n.s(ref, 'aiDesc'),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: theme.colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const AiBotPicker(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

/// Merges three Firestore streams for calls (callerId, calleeId, memberIds)
/// to avoid PERMISSION_DENIED on non-existent 'participants' field.
/// Sorts client-side to avoid needing composite indexes.
class _CallsStreamBuilder extends StatelessWidget {
  final String currentUid;
  final Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>)
  buildCallList;

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
              final aData = a.data();
              final bData = b.data();
              final aTime = aData['createdAt'] is Timestamp ? aData['createdAt'] as Timestamp : null;
              final bTime = bData['createdAt'] is Timestamp ? bData['createdAt'] as Timestamp : null;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

            if (allDocs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.call_outlined,
                      color: AppColors.aquaCore.withValues(alpha: 0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text('No call history', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      'Your calls will appear here',
                      style: AppTextStyles.caption,
                    ),
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
