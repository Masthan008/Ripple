import '../../../core/utils/haptic_feedback.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Add this
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/l10n.dart'; // Add this
import '../models/mood_config.dart';
import '../models/status_model.dart';
import '../services/status_service.dart';
import '../widgets/mood_aura_ring.dart';
import '../widgets/status_stories_carousel.dart';
import 'create_status_screen.dart';
import 'status_viewer_screen.dart';

/// Status list tab — shows My Status section + friends' recent updates.
/// Grouped by user, with mood aura rings on avatars.
class StatusListScreen extends ConsumerStatefulWidget {
  // Change to ConsumerStatefulWidget
  const StatusListScreen({super.key});

  @override
  ConsumerState<StatusListScreen> createState() => _StatusListScreenState();
}

class _StatusListScreenState extends ConsumerState<StatusListScreen> {
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<String> _mutedStatusUsers = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let HomeScreen handle background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text(L10n.s(ref, 'status'), style: AppTextStyles.heading),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white54,
                      size: 22,
                    ),
                    onPressed: () => _showStatusPrivacyMenu(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Horizontal Stories Carousel
            StreamBuilder<List<StatusModel>>(
              stream: StatusService.getMyStatuses(),
              builder: (context, mySnap) {
                final myStatuses = mySnap.data ?? [];
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseService.usersCollection.doc(_currentUid).snapshots(),
                  builder: (context, userSnap) {
                    final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final friends = List<String>.from(userData['friends'] as List? ?? []);

                    if (friends.isEmpty) {
                      return StatusStoriesCarousel(
                        myStatuses: myStatuses,
                        friendsGroupedStatuses: const {},
                        onAddStatusTap: _showCreateStatusSheet,
                      );
                    }

                    return StreamBuilder<List<StatusModel>>(
                      stream: StatusService.getFriendsStatuses(friends),
                      builder: (context, friendSnap) {
                        final allFriendsStatuses = friendSnap.data ?? [];
                        final grouped = <String, List<StatusModel>>{};
                        for (final s in allFriendsStatuses) {
                          grouped.putIfAbsent(s.uid, () => []).add(s);
                        }

                        return StatusStoriesCarousel(
                          myStatuses: myStatuses,
                          friendsGroupedStatuses: grouped,
                          onAddStatusTap: _showCreateStatusSheet,
                        );
                      },
                    );
                  },
                );
              },
            ),

            // My Status list tile
            _buildMyStatusSection(),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 1,
              ),
            ),

            // "Recent updates" label
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                L10n.s(ref, 'recentUpdates'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Friends statuses list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  AppHaptics.mediumTap();
                  await Future.delayed(const Duration(seconds: 1));
                  StatusService.cleanupExpired();
                },
                color: AppColors.aquaCore,
                backgroundColor: AppColors.abyssBackground.withOpacity(0.8),
                child: _buildFriendsStatusList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110.0), // Clear the high navbar
        child: FloatingActionButton(
          backgroundColor: AppColors.aquaCore,
          onPressed: () => _showCreateStatusSheet(),
          child: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMyStatusSection() {
    return StreamBuilder<List<StatusModel>>(
      stream: StatusService.getMyStatuses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('❌ My status stream error: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Failed to load status',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        final myStatuses = snapshot.data ?? [];

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseService.usersCollection.doc(_currentUid).snapshots(),
          builder: (context, userSnap) {
            final userData =
                userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final name = userData['name'] as String? ?? 'Me';
            final photo = userData['photoUrl'] as String? ?? '';

            return InkWell(
              onTap: () {
                if (myStatuses.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => StatusViewerScreen(
                            statuses: myStatuses,
                            initialIndex: 0,
                            viewerName: name,
                          ),
                    ),
                  );
                } else {
                  _showCreateStatusSheet();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Avatar with + button
                    Stack(
                      children: [
                        _buildStatusAvatar(
                          photo,
                          null,
                          28,
                          hasUnviewed: myStatuses.isNotEmpty,
                        ),
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
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L10n.s(ref, 'myStatus'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          myStatuses.isEmpty
                              ? L10n.s(ref, 'tapToAddStatus')
                              : '${myStatuses.length} ${L10n.s(ref, 'updates')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsStatusList() {
    // Get current user's friends list
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseService.usersCollection.doc(_currentUid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.aquaCore,
              strokeWidth: 2,
            ),
          );
        }

        final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final friends = List<String>.from(userData['friends'] as List? ?? []);
        _mutedStatusUsers = List<String>.from(
            userData['mutedStatuses'] as List? ?? []);
        debugPrint('👥 StatusListScreen: Found ${friends.length} friends for status feed');
        if (friends.isEmpty) {
          debugPrint('ℹ️ StatusListScreen: User has no friends yet — no statuses to show');
        }

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle_notifications_outlined,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  L10n.s(ref, 'noStatusUpdates'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  L10n.s(ref, 'addFriendsToSeeUpdates'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<List<StatusModel>>(
          stream: StatusService.getFriendsStatuses(friends),
          builder: (context, statusSnap) {
            if (statusSnap.hasError) {
              debugPrint(
                '\u274c Friend status stream error: ${statusSnap.error}',
              );
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load statuses',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (!statusSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.aquaCore,
                  strokeWidth: 2,
                ),
              );
            }

            final allStatuses = statusSnap.data ?? [];
            if (allStatuses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.circle_notifications_outlined,
                      color: Colors.white.withValues(alpha: 0.15),
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      L10n.s(ref, 'noRecentUpdates'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Group statuses by user
            final grouped = <String, List<StatusModel>>{};
            for (final status in allStatuses) {
              grouped.putIfAbsent(status.uid, () => []).add(status);
            }

            final sortedKeys = grouped.keys.toList()
              ..sort((a, b) {
                final aMuted = _mutedStatusUsers.contains(a) ? 1 : 0;
                final bMuted = _mutedStatusUsers.contains(b) ? 1 : 0;
                return aMuted.compareTo(bMuted);
              });

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: sortedKeys.length,
              itemBuilder: (context, i) {
                final uid = sortedKeys[i];
                final userStatuses = grouped[uid]!;
                final latest = userStatuses.first;

                // Check if all viewed by current user
                final allViewed = userStatuses.every(
                  (s) => s.viewers.any((v) => v['uid'] == _currentUid),
                );

                // Check for mood status
                final moodStatus =
                    userStatuses
                        .where((s) => s.type == 'mood' && s.mood != null)
                        .toList();

                return _buildStatusListTile(
                  userStatuses: userStatuses,
                  latest: latest,
                  allViewed: allViewed,
                  mood: moodStatus.isNotEmpty ? moodStatus.first.mood : null,
                  isMuted: _mutedStatusUsers.contains(uid),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatusListTile({
    required List<StatusModel> userStatuses,
    required StatusModel latest,
    required bool allViewed,
    String? mood,
    bool isMuted = false,
  }) {
    return GestureDetector(
      onLongPress: () => _showMuteMenu(latest.uid, latest.ownerName, isMuted),
      child: Opacity(
        opacity: isMuted ? 0.4 : 1.0,
        child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _buildStatusAvatar(
        latest.ownerPhoto,
        mood,
        26,
        hasUnviewed: !allViewed,
      ),
      title: Text(
        latest.ownerName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        _timeAgo(ref, latest.createdAt),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (latest.commentCount > 0) ...[
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              '${latest.commentCount}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (mood != null)
            Icon(
              MoodConfig.getIcon(mood),
              size: 20,
              color: AppColors.aquaCore,
            ),
        ],
      ),
      onTap: () {
        final userName = FirebaseAuth.instance.currentUser?.displayName ?? '';
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => StatusViewerScreen(
                  statuses: userStatuses,
                  initialIndex: 0,
                  viewerName: userName,
                ),
          ),
        );
      },
    ),
    ),
    );
  }

  Widget _buildStatusAvatar(
    String photoUrl,
    String? mood,
    double radius, {
    bool hasUnviewed = false,
  }) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1A2A40),
      backgroundImage:
          photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
      child:
          photoUrl.isEmpty
              ? Icon(Icons.person, color: Colors.white38, size: radius)
              : null,
    );

    // Wrap with mood aura if mood is set
    if (mood != null) {
      return MoodAuraRing(mood: mood, radius: radius, child: avatar);
    }

    // Status ring (colored if unviewed, grey if all viewed)
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            hasUnviewed
                ? const LinearGradient(
                  colors: [AppColors.aquaCore, AppColors.aquaCyan],
                )
                : null,
        border:
            hasUnviewed
                ? null
                : Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 2,
                ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.abyssBackground,
        ),
        child: avatar,
      ),
    );
  }

  void _showCreateStatusSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateStatusSheet(),
    );
  }

  String _timeAgo(WidgetRef ref, Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return L10n.s(ref, 'justNow');
    if (diff.inMinutes < 60) return '${diff.inMinutes}${L10n.s(ref, 'mAgo')}';
    if (diff.inHours < 24) return '${diff.inHours}${L10n.s(ref, 'hAgo')}';
    return DateFormat('MMM d').format(ts.toDate());
  }

  // ── Status Privacy Menu ─────────────────────────────────
  void _showStatusPrivacyMenu(BuildContext context) {
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
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Status Privacy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _privacyOption(
            icon: Icons.people_rounded,
            title: 'My contacts',
            subtitle: 'Share with all your contacts',
            value: 'friends',
          ),
          _privacyOption(
            icon: Icons.people_outline_rounded,
            title: 'My contacts except...',
            subtitle: 'Share with contacts, excluding select people',
            value: 'friends_except',
          ),
          _privacyOption(
            icon: Icons.person_add_rounded,
            title: 'Only share with...',
            subtitle: 'Only selected contacts will see your status',
            value: 'only_share_with',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _privacyOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.aquaCore, size: 24),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
      ),
      onTap: () async {
        Navigator.pop(context);
        await FirebaseService.firestore
            .collection('users')
            .doc(_currentUid)
            .update({'statusPrivacy': value});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status privacy set to: $title'),
              backgroundColor: AppColors.aquaCore,
            ),
          );
        }
      },
    );
  }

  // ── Mute / Unmute Status ────────────────────────────────
  void _showMuteMenu(String uid, String name, bool currentlyMuted) {
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
              currentlyMuted
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: AppColors.aquaCore,
            ),
            title: Text(
              currentlyMuted ? 'Unmute $name' : 'Mute $name',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              currentlyMuted
                  ? 'You will see their status updates again'
                  : 'Their updates will be hidden from your feed',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseService.firestore
                  .collection('users')
                  .doc(_currentUid)
                  .update({
                'mutedStatuses': currentlyMuted
                    ? FieldValue.arrayRemove([uid])
                    : FieldValue.arrayUnion([uid]),
              });
              AppHaptics.mediumTap();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        currentlyMuted ? '$name unmuted' : '$name muted'),
                    backgroundColor: AppColors.aquaCore,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
