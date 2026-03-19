import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../models/mood_config.dart';
import '../models/status_model.dart';
import '../services/status_service.dart';
import '../widgets/mood_aura_ring.dart';
import 'create_status_screen.dart';
import 'status_viewer_screen.dart';

/// Status list tab — shows My Status section + friends' recent updates.
/// Grouped by user, with mood aura rings on avatars.
class StatusListScreen extends StatefulWidget {
  const StatusListScreen({super.key});

  @override
  State<StatusListScreen> createState() => _StatusListScreenState();
}

class _StatusListScreenState extends State<StatusListScreen> {
  final _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text('Status', style: AppTextStyles.heading),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white54, size: 22),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // My Status section
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
                'Recent updates',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Friends statuses list
            Expanded(child: _buildFriendsStatusList()),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0), // Clear the high navbar
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
                Icon(Icons.error_outline,
                    color: Colors.white.withValues(alpha: 0.3), size: 28),
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
          stream: FirebaseService.usersCollection
              .doc(_currentUid)
              .snapshots(),
          builder: (context, userSnap) {
            final userData =
                userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final name = userData['name'] as String? ?? 'Me';
            final photo = userData['photoUrl'] as String? ?? '';

            return InkWell(
              onTap: () {
                if (myStatuses.isNotEmpty) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StatusViewerScreen(
                      statuses: myStatuses,
                      initialIndex: 0,
                      viewerName: name,
                    ),
                  ));
                } else {
                  _showCreateStatusSheet();
                }
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    // Avatar with + button
                    Stack(
                      children: [
                        _buildStatusAvatar(photo, null, 28,
                            hasUnviewed: myStatuses.isNotEmpty),
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
                            child: const Icon(Icons.add,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          myStatuses.isEmpty
                              ? 'Tap to add status update'
                              : '${myStatuses.length} update${myStatuses.length > 1 ? "s" : ""}',
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
      stream:
          FirebaseService.usersCollection.doc(_currentUid).snapshots(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppColors.aquaCore, strokeWidth: 2),
          );
        }

        final userData =
            userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final friends =
            List<String>.from(userData['friends'] as List? ?? []);

        if (friends.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle_notifications_outlined,
                    color: Colors.white.withValues(alpha: 0.15), size: 64),
                const SizedBox(height: 12),
                Text(
                  'No status updates yet',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add friends to see their updates',
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
              debugPrint('\u274c Friend status stream error: ${statusSnap.error}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 48),
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
                    color: AppColors.aquaCore, strokeWidth: 2),
              );
            }

            final allStatuses = statusSnap.data ?? [];
            if (allStatuses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.circle_notifications_outlined,
                        color: Colors.white.withValues(alpha: 0.15),
                        size: 64),
                    const SizedBox(height: 12),
                    Text(
                      'No recent updates',
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

            final sortedKeys = grouped.keys.toList();

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: sortedKeys.length,
              itemBuilder: (context, i) {
                final uid = sortedKeys[i];
                final userStatuses = grouped[uid]!;
                final latest = userStatuses.first;

                // Check if all viewed by current user
                final allViewed = userStatuses.every((s) => s.viewers
                    .any((v) => v['uid'] == _currentUid));

                // Check for mood status
                final moodStatus = userStatuses
                    .where((s) => s.type == 'mood' && s.mood != null)
                    .toList();

                return _buildStatusListTile(
                  userStatuses: userStatuses,
                  latest: latest,
                  allViewed: allViewed,
                  mood: moodStatus.isNotEmpty
                      ? moodStatus.first.mood
                      : null,
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
  }) {
    return ListTile(
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
        _timeAgo(latest.createdAt),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 12,
        ),
      ),
      trailing: mood != null
          ? Text(MoodConfig.getEmoji(mood), style: const TextStyle(fontSize: 20))
          : null,
      onTap: () {
        final userName = FirebaseAuth.instance.currentUser?.displayName ?? '';
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => StatusViewerScreen(
            statuses: userStatuses,
            initialIndex: 0,
            viewerName: userName,
          ),
        ));
      },
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
      child: photoUrl.isEmpty
          ? Icon(Icons.person, color: Colors.white38, size: radius)
          : null,
    );

    // Wrap with mood aura if mood is set
    if (mood != null) {
      return MoodAuraRing(
        mood: mood,
        radius: radius,
        child: avatar,
      );
    }

    // Status ring (colored if unviewed, grey if all viewed)
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnviewed
            ? const LinearGradient(
                colors: [AppColors.aquaCore, AppColors.aquaCyan],
              )
            : null,
        border: hasUnviewed
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

  String _timeAgo(Timestamp ts) {
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(ts.toDate());
  }
}
