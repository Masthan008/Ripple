import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
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
  bool _isLoading = true;
  UserModel? _user;
  List<Map<String, dynamic>> _mutualFriends = [];
  int _rippleScore = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final myUid = ref.read(chatServiceProvider).myUid;
      final me = ref.read(currentUserProvider).valueOrNull;

      // Record profile visit if user exists
      if (me != null) {
        await SocialService.recordProfileVisit(
          profileOwnerId: widget.uid,
          visitorId: myUid,
          visitorName: me.name,
          visitorPhoto: me.photoUrl ?? '',
        );
      }

      final doc =
          await FirebaseService.usersCollection.doc(widget.uid).get();
      if (doc.exists) {
        _user = UserModel.fromFirestore(doc);
        final data = doc.data()!;
        _rippleScore = data['rippleScore'] as int? ?? 0;

        _mutualFriends = await SocialService.getMutualFriends(
          currentUid: myUid,
          targetUid: widget.uid,
        );
      }
    } catch (e) {
      debugPrint('Error loading other profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.abyssBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.aquaCore),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: AppColors.abyssBackground,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Text('User not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text(_user!.name, style: AppTextStyles.headingSmall),
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
                  imageUrl: _user!.photoUrl,
                  name: _user!.name,
                  size: 100,
                  showOnlineDot: true,
                  isOnline: _user!.isOnline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _user!.name,
              style: AppTextStyles.display.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: SocialService.getRippleRankColor(_rippleScore)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        SocialService.getRippleRank(_rippleScore),
                        style: TextStyle(
                          color: SocialService.getRippleRankColor(_rippleScore),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _rippleScore.toString(),
                        style: TextStyle(
                          color: SocialService.getRippleRankColor(_rippleScore),
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
