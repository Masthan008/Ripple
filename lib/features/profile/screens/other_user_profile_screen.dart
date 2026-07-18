import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../social/widgets/achievements_section.dart';

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


  @override
  Widget build(BuildContext context) {
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
          return Scaffold(
            backgroundColor: AppColors.abyssBackground,
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(
              child: Text('User not found', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        final user = snapshot.data!.data() as Map<String, dynamic>?;
        if (user == null) {
          return const SizedBox.shrink();
        }

        final privacy = user['privacy'] as Map<String, dynamic>? ?? {};
        final rippleScore = user['rippleScore'] as int? ?? 0;
        final myUid = ref.read(chatServiceProvider).myUid;
        final me = ref.read(currentUserProvider).valueOrNull;
        final myFriends = me?.friends is List ? List<String>.from(me!.friends as List) : <String>[];
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

        return Scaffold(
          backgroundColor: AppColors.abyssBackground,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    user['name'] as String? ?? 'User',
                    style: AppTextStyles.headingSmall,
                  ),
                ),
                VerifiedBadge(
                  isVerified: user['isVerified'] as bool? ?? false,
                  size: 14,
                ),
              ],
            ),
            backgroundColor: Colors.transparent,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
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
                      size: 100,
                      showOnlineDot: true,
                      isOnline: isOnline && (user['isOnline'] as bool? ?? false),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        user['name'] as String? ?? 'User',
                        style: AppTextStyles.display.copyWith(fontSize: 26),
                      ),
                    ),
                    VerifiedBadge(
                      isVerified: user['isVerified'] as bool? ?? false,
                      size: 24,
                      padding: const EdgeInsets.only(left: 6),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: SocialService.getRippleRankColor(rippleScore)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            SocialService.getRippleRank(rippleScore),
                            style: TextStyle(
                              color: SocialService.getRippleRankColor(rippleScore),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            rippleScore.toString(),
                            style: TextStyle(
                              color: SocialService.getRippleRankColor(rippleScore),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                AchievementsSection(uid: widget.uid),
                const SizedBox(height: 24),
                _buildMutualFriendsSection(),
              ],
            ),
          ),
        );
      },
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
