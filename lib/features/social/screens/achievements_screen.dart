import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/social_service.dart';
import '../models/achievement_model.dart';
import 'package:intl/intl.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.abyssBackground,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Achievements', style: AppTextStyles.headingSmall),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<AchievementModel>>(
        stream: SocialService.getAchievements(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
          }
          final unlocked = snapshot.data ?? [];
          final allDefs = AchievementDefinitions.all;
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '${unlocked.length} / ${allDefs.length}',
                        style: AppTextStyles.display.copyWith(fontSize: 32, color: AppColors.aquaCore),
                      ),
                      const SizedBox(height: 4),
                      Text('Achievements Unlocked', style: AppTextStyles.caption),
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: allDefs.isEmpty ? 0 : unlocked.length / allDefs.length,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(AppColors.aquaCore),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final def = allDefs[index];
                      final isUnlocked = unlocked.any((a) => a.id == def.id);
                      final achievement = isUnlocked ? unlocked.firstWhere((a) => a.id == def.id) : null;
                      
                      return GestureDetector(
                        onTap: () => _showDetails(context, def, achievement),
                        child: _AchievementCard(
                          definition: def,
                          isUnlocked: isUnlocked,
                        ),
                      );
                    },
                    childCount: allDefs.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, AchievementModel def, AchievementModel? unlocked) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked != null 
                      ? _getTierColor(def.tier).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: unlocked != null
                        ? _getTierColor(def.tier)
                        : Colors.white24,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    def.emoji,
                    style: TextStyle(fontSize: 36, color: unlocked == null ? Colors.transparent : null),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                def.title,
                style: AppTextStyles.headingSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                def.description,
                style: AppTextStyles.body.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (unlocked != null && unlocked.unlockedAt != null)
                Text(
                  'Unlocked ${DateFormat('MMM d, y').format(unlocked.unlockedAt!.toDate())}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.aquaCore),
                )
              else
                Text(
                  'Locked',
                  style: AppTextStyles.caption.copyWith(color: Colors.white54),
                ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTierColor(AchievementTier tier) {
    switch (tier) {
      case AchievementTier.bronze:
        return const Color(0xFFCD7F32);
      case AchievementTier.silver:
        return const Color(0xFF94A3B8);
      case AchievementTier.gold:
        return const Color(0xFFFFD700);
      case AchievementTier.diamond:
        return const Color(0xFF22D3EE);
    }
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementModel definition;
  final bool isUnlocked;

  const _AchievementCard({
    required this.definition,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getTierColor(definition.tier);
    
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked 
                  ? color.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isUnlocked ? color.withValues(alpha: 0.5) : Colors.white12,
                width: 2,
              ),
            ),
            child: Center(
              child: isUnlocked
                  ? Text(definition.emoji, style: const TextStyle(fontSize: 32))
                  : const Icon(Icons.lock_rounded, color: Colors.white24, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          definition.title,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: isUnlocked ? Colors.white : Colors.white54,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
        return const Color(0xFFFFD700);
      case AchievementTier.diamond:
        return const Color(0xFF22D3EE);
    }
  }
}
