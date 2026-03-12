import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../friends/providers/friends_provider.dart';
import '../services/social_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityFeedScreen extends ConsumerStatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  ConsumerState<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends ConsumerState<ActivityFeedScreen> {
  // We'll store pre-fetched buddy details here to avoid N+1 queries in build
  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // In a real app we might fetch user details as they appear, 
    // but caching the friends list upfront is easier here.
    _preloadUsers();
  }

  Future<void> _preloadUsers() async {
    try {
      final friends = ref.read(friendsListProvider).valueOrNull ?? [];
      for (final f in friends) {
        _userCache[f.uid] = {
          'name': f.name,
          'photoUrl': f.photoUrl,
        };
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.abyssBackground,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator(color: AppColors.aquaCore)),
      );
    }

    final friends = ref.watch(friendsListProvider).valueOrNull ?? [];
    final friendUids = friends.map((f) => f.uid).toList();

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Activity Feed', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SocialService.getFriendsActivity(friendUids),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, size: 60, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text('No recent activity from friends.', style: AppTextStyles.body),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              final uid = act['uid'] as String;
              final user = _userCache[uid];
              final name = user?['name'] ?? 'A friend';
              final photo = user?['photoUrl'];
              final createdAt = act['createdAt'] as Timestamp?;
              final timeString = createdAt != null 
                  ? timeago.format(createdAt.toDate())
                  : 'just now';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AquaAvatar(
                        imageUrl: photo as String?,
                        name: name as String,
                        size: 40,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: AppTextStyles.body,
                                children: [
                                  TextSpan(
                                    text: '$name ',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: act['title'] as String? ?? 'did something',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  TextSpan(
                                    text: ' ${act['emoji'] ?? ''}',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(timeString, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
