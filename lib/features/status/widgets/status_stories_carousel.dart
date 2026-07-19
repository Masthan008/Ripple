import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mood_config.dart';
import '../models/status_model.dart';
import '../screens/status_viewer_screen.dart';
import '../widgets/mood_aura_ring.dart';

/// Instagram/WhatsApp-style horizontal stories carousel.
class StatusStoriesCarousel extends StatelessWidget {
  final List<StatusModel> myStatuses;
  final Map<String, List<StatusModel>> friendsGroupedStatuses;
  final VoidCallback onAddStatusTap;

  const StatusStoriesCarousel({
    super.key,
    required this.myStatuses,
    required this.friendsGroupedStatuses,
    required this.onAddStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return SizedBox(
      height: 110,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myUid).snapshots(),
        builder: (context, snapshot) {
          final myData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final myPhoto = myData['photoUrl'] as String? ?? '';
          final myName = myData['name'] as String? ?? 'Me';

          final friendUids = friendsGroupedStatuses.keys.toList();

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 1 + friendUids.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                // My Status Bubble
                return _buildMyStatusBubble(
                  context,
                  myPhoto: myPhoto,
                  myName: myName,
                  myStatuses: myStatuses,
                );
              }

              final friendUid = friendUids[index - 1];
              final userStatuses = friendsGroupedStatuses[friendUid]!;
              final latest = userStatuses.first;

              final allViewed = userStatuses.every(
                (s) => s.viewers.any((v) => v['uid'] == myUid),
              );

              final moodStatus = userStatuses
                  .where((s) => s.type == 'mood' && s.mood != null)
                  .toList();
              final mood = moodStatus.isNotEmpty ? moodStatus.first.mood : null;

              return _buildFriendStatusBubble(
                context,
                userStatuses: userStatuses,
                latest: latest,
                allViewed: allViewed,
                mood: mood,
                viewerName: myName,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMyStatusBubble(
    BuildContext context, {
    required String myPhoto,
    required String myName,
    required List<StatusModel> myStatuses,
  }) {
    return GestureDetector(
      onTap: () {
        if (myStatuses.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StatusViewerScreen(
                statuses: myStatuses,
                initialIndex: 0,
                viewerName: myName,
              ),
            ),
          );
        } else {
          onAddStatusTap();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 72,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: myStatuses.isNotEmpty
                        ? const LinearGradient(
                            colors: [AppColors.aquaCore, AppColors.aquaCyan],
                          )
                        : null,
                    border: myStatuses.isEmpty
                        ? Border.all(color: Colors.white24, width: 2)
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF1A2A40),
                    backgroundImage: myPhoto.isNotEmpty
                        ? CachedNetworkImageProvider(myPhoto)
                        : null,
                    child: myPhoto.isEmpty
                        ? const Icon(Icons.person, color: Colors.white54, size: 28)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.aquaCore,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF060D1A),
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
            const SizedBox(height: 6),
            const Text(
              'Your Status',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendStatusBubble(
    BuildContext context, {
    required List<StatusModel> userStatuses,
    required StatusModel latest,
    required bool allViewed,
    String? mood,
    required String viewerName,
  }) {
    final avatar = CircleAvatar(
      radius: 28,
      backgroundColor: const Color(0xFF1A2A40),
      backgroundImage: latest.ownerPhoto.isNotEmpty
          ? CachedNetworkImageProvider(latest.ownerPhoto)
          : null,
      child: latest.ownerPhoto.isEmpty
          ? Text(
              latest.ownerName.isNotEmpty
                  ? latest.ownerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )
          : null,
    );

    Widget avatarWidget;
    if (mood != null) {
      avatarWidget = MoodAuraRing(mood: mood, radius: 28, child: avatar);
    } else {
      avatarWidget = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: !allViewed
              ? const LinearGradient(
                  colors: [AppColors.aquaCore, AppColors.aquaCyan],
                )
              : null,
          border: allViewed
              ? Border.all(color: Colors.white24, width: 2)
              : null,
        ),
        child: avatar,
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StatusViewerScreen(
              statuses: userStatuses,
              initialIndex: 0,
              viewerName: viewerName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 72,
        child: Column(
          children: [
            avatarWidget,
            const SizedBox(height: 6),
            Text(
              latest.ownerName,
              style: TextStyle(
                color: allViewed ? Colors.white60 : Colors.white,
                fontSize: 11,
                fontWeight: allViewed ? FontWeight.normal : FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
