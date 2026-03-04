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
import '../../../shared/widgets/ripple_nav_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../profile/screens/profile_screen.dart';

/// Home screen with Telegram-style RippleNavBar — glass design per PRD §4.3
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  AppLifecycleObserver? _lifecycleObserver;

  final _tabs = const [
    _ChatsTab(),
    _GroupsTab(),
    _CallsTab(),
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
      }
    });
  }

  @override
  void dispose() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: myUid != null
          ? _buildNavBarWithUnread(myUid, currentUser?.photoUrl)
          : RippleNavBar(
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
            final unread = doc.data()['unreadCount'] as Map<String, dynamic>?;
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
                final unread =
                    doc.data()['unreadCount'] as Map<String, dynamic>?;
                totalGroupUnread += (unread?[myUid] as int?) ?? 0;
              }
            }

            return RippleNavBar(
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              unreadCounts: [totalChatUnread, totalGroupUnread, 0, 0],
              userPhotoUrl: photoUrl,
            );
          },
        );
      },
    );
  }
}

// ─── Tab Stubs (Phase 2+) ────────────────────────────────

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                // Friend requests button with badge
                _GlassIconButton(
                  icon: Icons.person_add_rounded,
                  onTap: () => GoRouter.of(context).push('/requests'),
                ),
                const SizedBox(width: 8),
                // Discover people button
                _GlassIconButton(
                  icon: Icons.explore_rounded,
                  onTap: () => GoRouter.of(context).push('/users'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your conversations',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 16),
            // Search bar
            _ChatSearchBar(
              chatsStream: currentUser == null
                  ? null
                  : FirebaseService.chatsCollection
                      .where('participants',
                          arrayContains: currentUser.uid)
                      .snapshots()
                      .handleError((_) {}),
              currentUid: currentUser?.uid ?? '',
            ),
            const SizedBox(height: 16),
            // Chat list
            Expanded(
              child: currentUser == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                                const SizedBox(height: 4),
                                Text(
                                  'Deploy Firestore rules first:\nFirebase Console → Firestore → Rules → Publish',
                                  style: AppTextStyles.caption,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final chats = snapshot.data?.docs ?? [];

                        if (chats.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.water_drop_outlined,
                                    color: AppColors.aquaCore
                                        .withValues(alpha: 0.3),
                                    size: 64),
                                const SizedBox(height: 12),
                                Text('No conversations yet',
                                    style: AppTextStyles.bodySmall),
                                const SizedBox(height: 4),
                                Text('Start chatting with friends!',
                                    style: AppTextStyles.caption),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: chats.length,
                          itemBuilder: (ctx, i) {
                            final data = chats[i].data();
                            final participants = List<String>.from(
                                data['participants'] ?? []);
                            final otherUid = participants.firstWhere(
                              (id) => id != currentUser.uid,
                              orElse: () => '',
                            );
                            if (otherUid.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return _ChatTile(
                              chatId: chats[i].id,
                              otherUid: otherUid,
                              lastMessage: data['lastMessage']
                                  as Map<String, dynamic>?,
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

    for (final chatDoc in _allChats) {
      final data = chatDoc.data();
      final participants =
          List<String>.from(data['participants'] ?? []);
      final otherUid = participants.firstWhere(
        (id) => id != widget.currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty) continue;

      // Fetch partner name
      try {
        final userDoc = await FirebaseService.usersCollection
            .doc(otherUid)
            .get();
        final name =
            (userDoc.data()?['name'] as String? ?? '').toLowerCase();
        if (name.contains(lowerQuery)) {
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

  @override
  Widget build(BuildContext context) {
    // Listen to chats stream to populate _allChats for search
    if (widget.chatsStream != null) {
      widget.chatsStream!.listen((snapshot) {
        _allChats = snapshot.docs;
      });
    }

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
class _ChatTile extends StatelessWidget {
  final String chatId;
  final String otherUid;
  final Map<String, dynamic>? lastMessage;

  const _ChatTile({
    required this.chatId,
    required this.otherUid,
    this.lastMessage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseService.usersCollection.doc(otherUid).get(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final userData = snap.data!.data()!;
        final name = userData['name'] ?? 'User';
        final photoUrl = userData['photoUrl'] ?? '';
        final isOnline = userData['isOnline'] ?? false;

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
              onTap: () {
                GoRouter.of(context).push(
                  '/chat?chatId=$chatId&partnerUid=$otherUid&partnerName=${Uri.encodeComponent(name)}&partnerPhoto=${Uri.encodeComponent(photoUrl)}',
                );
              },
              child: Row(
                children: [
                  // Avatar with online dot
                  Stack(
                    children: [
                      AquaAvatar(
                        imageUrl: photoUrl.isNotEmpty ? photoUrl : null,
                        name: name,
                        size: 44,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTextStyles.body
                                .copyWith(fontSize: 14)),
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
                  if (timeStr.isNotEmpty)
                    Text(timeStr,
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 10)),
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

