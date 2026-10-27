import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/achievement_model.dart';
import '../services/social_service.dart';

class AchievementsSection extends StatelessWidget {
  final String uid;

  const AchievementsSection({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AchievementModel>>(
      stream: SocialService.getAchievements(uid),
      builder: (context, snapshot) {
        final achievements = snapshot.data ?? [];
        final totalXp = AchievementDefinitions.calculateTotalXp(achievements);
        final currentRank = UserRank.forXp(totalXp);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'SECURITY ACHIEVEMENTS',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: AppColors.aquaCore.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => GoRouter.of(context).push('/achievements'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: currentRank.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: currentRank.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(currentRank.icon, size: 12, color: currentRank.color),
                        const SizedBox(width: 4),
                        Text(
                          '${currentRank.title} • $totalXp XP',
                          style: TextStyle(
                            color: currentRank.color,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 14, color: currentRank.color),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator(color: AppColors.aquaCore)),
              )
            else if (achievements.isEmpty)
              GestureDetector(
                onTap: () => GoRouter.of(context).push('/achievements'),
                child: GlassCard(
                  borderRadius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Unlock encrypted achievements and climb the security ranks.',
                          style: AppTextStyles.caption.copyWith(color: Colors.white60),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 94,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final ach = achievements[index];
                    final tierColor = _getTierColor(ach.tier);

                    return GestureDetector(
                      onTap: () => GoRouter.of(context).push('/achievements'),
                      child: Container(
                        width: 82,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tierColor.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: tierColor.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Icon(ach.icon, size: 24, color: tierColor),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ach.title,
                              style: AppTextStyles.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '+${ach.xpReward} XP',
                              style: TextStyle(fontSize: 9, color: tierColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getTierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFF94A3B8);
      case AchievementTier.gold:
        return const Color(0xFFF59E0B);
      case AchievementTier.diamond:
        return const Color(0xFF22D3EE);
    }
  }
}
