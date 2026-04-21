import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../models/challenge_model.dart';

/// Community Challenges Screen - Weekly challenges with badges and rewards
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  @override
  Widget build(BuildContext context) {
    final challenges = WeeklyChallenges.defaultChallenges;
    final badges = WeeklyChallenges.availableBadges;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          const FloatingParticles(particleCount: 2),
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: const Color(0xFF0A1628),
                expandedHeight: 200,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'Weekly Challenges',
                    style: TextStyle(color: Colors.white),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.aquaCore.withValues(alpha: 0.3),
                          AppColors.aquaCyan.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Earn Badges & Rewards',
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Challenges Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Active Challenges'),
                      const SizedBox(height: 12),
                      ...challenges.asMap().entries.map((entry) {
                        return AnimationConfiguration.staggeredList(
                          position: entry.key,
                          duration: const Duration(milliseconds: 300),
                          child: SlideAnimation(
                            verticalOffset: 50,
                            child: FadeInAnimation(
                              child: _ChallengeCard(
                                challenge: entry.value,
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      _sectionHeader('Available Badges'),
                      const SizedBox(height: 12),
                      _BadgesGrid(badges: badges),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: TextStyle(
          color: AppColors.aquaCore,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final isCompleted = challenge.isCompleted;
    final progress = challenge.progressPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCompleted
              ? [
                  Colors.green.withValues(alpha: 0.2),
                  Colors.green.withValues(alpha: 0.05),
                ]
              : [
                  AppColors.glassPanel,
                  AppColors.glassPanel.withValues(alpha: 0.5),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.5)
              : AppColors.aquaCyan.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: isCompleted ? Colors.green : Colors.white,
                  ),
                ),
              ),
              if (isCompleted)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.aquaCore.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${challenge.reward}',
                    style: const TextStyle(
                      color: AppColors.aquaCore,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            challenge.description,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                isCompleted ? Colors.green : AppColors.aquaCore,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${challenge.currentProgress}/${challenge.target}',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              if (challenge.badgeId != null)
                Row(
                  children: [
                    const Icon(
                      Icons.military_tech,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Badge Reward',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgesGrid extends StatelessWidget {
  final List<BadgeModel> badges;

  const _BadgesGrid({required this.badges});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        return _BadgeCard(badge: badges[index]);
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeModel badge;

  const _BadgeCard({required this.badge});

  Color get rarityColor {
    switch (badge.rarity) {
      case 'common':
        return Colors.grey;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rarityColor.withValues(alpha: 0.2),
            rarityColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              badge.icon,
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: AppTextStyles.bodySmall.copyWith(
              color: rarityColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            badge.rarity.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: rarityColor.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
