import 'package:flutter/material.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'ACHIEVEMENTS',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: AppColors.aquaCore.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<AchievementModel>>(
          stream: SocialService.getAchievements(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final achievements = snapshot.data ?? [];
            if (achievements.isEmpty) {
              return GlassCard(
                borderRadius: 14,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No achievements yet.',
                    style: AppTextStyles.caption,
                  ),
                ),
              );
            }

            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final ach = achievements[index];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getTierColor(ach.tier).withValues(alpha: 0.15),
                            border: Border.all(
                              color: _getTierColor(ach.tier).withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(ach.emoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ach.title,
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
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
