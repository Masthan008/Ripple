import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../friends/providers/friends_provider.dart';
import '../services/social_service.dart';
import 'package:go_router/go_router.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final friends = ref.read(friendsListProvider).valueOrNull ?? [];
      final friendUids = friends.map((f) => f.uid).toList();
      _leaderboard = await SocialService.getFriendsLeaderboard(friendUids);
    } catch (e) {
      debugPrint('Leaderboard error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Leaderboard', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.aquaCore))
          : _leaderboard.isEmpty
              ? Center(
                  child: Text('No data available.', style: AppTextStyles.body),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaderboard.length,
                  itemBuilder: (context, index) {
                    final user = _leaderboard[index];
                    final rank = index + 1;
                    final isTop3 = rank <= 3;
                    final score = user['rippleScore'] as int? ?? 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        borderRadius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30,
                              child: Text(
                                '#$rank',
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: isTop3 ? Colors.amber : Colors.white54,
                                  fontSize: isTop3 ? 18 : 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.push('/other-profile?uid=${user['uid']}'),
                              child: AquaAvatar(
                                imageUrl: user['photoUrl'] as String?,
                                name: user['name'] as String? ?? 'User',
                                size: 44,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['name'] as String? ?? 'User',
                                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    SocialService.getRippleRank(score),
                                    style: AppTextStyles.caption.copyWith(
                                      color: SocialService.getRippleRankColor(score),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: SocialService.getRippleRankColor(score).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: SocialService.getRippleRankColor(score).withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '🌊',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    score.toString(),
                                    style: TextStyle(
                                      color: SocialService.getRippleRankColor(score),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
