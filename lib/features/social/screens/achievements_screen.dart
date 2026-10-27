import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/achievement_model.dart';
import '../services/social_service.dart';

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementTrack? _selectedTrack;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.abyssBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.aquaCore)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: const Text(
          'Security & Network Achievements',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.aquaCore),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<AchievementModel>>(
        stream: SocialService.getAchievements(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
          }

          final unlocked = snapshot.data ?? [];
          final totalXp = AchievementDefinitions.calculateTotalXp(unlocked);
          final currentRank = UserRank.forXp(totalXp);

          // Calculate next rank target
          final rankIdx = UserRank.ranks.indexOf(currentRank);
          final nextRank = rankIdx < UserRank.ranks.length - 1 ? UserRank.ranks[rankIdx + 1] : null;
          final xpSpan = nextRank != null ? (nextRank.minXp - currentRank.minXp) : 1;
          final xpProgress = nextRank != null
              ? ((totalXp - currentRank.minXp) / xpSpan).clamp(0.0, 1.0)
              : 1.0;

          // Filter by track
          final allDefs = AchievementDefinitions.all;
          final filtered = _selectedTrack == null
              ? allDefs
              : allDefs.where((a) => a.track == _selectedTrack).toList();

          return CustomScrollView(
            slivers: [
              // ─── Rank & Total XP Header Card ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          currentRank.color.withValues(alpha: 0.18),
                          const Color(0xFF0F172A).withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: currentRank.color.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentRank.color.withValues(alpha: 0.15),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentRank.color.withValues(alpha: 0.2),
                                border: Border.all(color: currentRank.color, width: 1.5),
                              ),
                              child: Icon(currentRank.icon, color: currentRank.color, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        currentRank.title,
                                        style: TextStyle(
                                          color: currentRank.color,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Rank ${rankIdx + 1}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$totalXp XP Total • ${unlocked.length} of ${allDefs.length} Unlocked',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Progress Bar to Next Rank
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: xpProgress,
                            minHeight: 8,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(currentRank.color),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$totalXp XP',
                              style: TextStyle(color: currentRank.color, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              nextRank != null
                                  ? '${nextRank.minXp - totalXp} XP to ${nextRank.title}'
                                  : 'Apex Rank Achieved',
                              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Track Filter Tabs ──────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildTrackChip(label: 'All Tracks', track: null),
                      ...AchievementTrack.values.map((t) => _buildTrackChip(label: t.label, track: t)),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ─── Achievements Grid ──────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final def = filtered[index];
                      final isUnlocked = unlocked.any((a) => a.id == def.id);
                      final userItem = isUnlocked ? unlocked.firstWhere((a) => a.id == def.id) : null;

                      return GestureDetector(
                        onTap: () => _showDetails(context, def, userItem),
                        child: _AchievementCard(
                          definition: def,
                          isUnlocked: isUnlocked,
                        ),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 36)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackChip({required String label, required AchievementTrack? track}) {
    final isSelected = _selectedTrack == track;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedTrack = track),
        selectedColor: AppColors.aquaCore.withValues(alpha: 0.2),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.aquaCore : Colors.white60,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.aquaCore.withValues(alpha: 0.5) : Colors.white12,
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, AchievementModel def, AchievementModel? unlocked) {
    final tierColor = _getTierColor(def.tier);

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: tierColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked != null
                      ? tierColor.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: unlocked != null ? tierColor : Colors.white24,
                    width: 2,
                  ),
                  boxShadow: unlocked != null
                      ? [
                          BoxShadow(
                            color: tierColor.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    def.icon,
                    size: 34,
                    color: unlocked != null ? tierColor : Colors.white24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                def.title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${def.tier.name.toUpperCase()} • +${def.xpReward} XP',
                  style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                def.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (unlocked != null && unlocked.unlockedAt != null)
                Text(
                  'Unlocked on ${DateFormat('MMM d, y').format(unlocked.unlockedAt!.toDate())}',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                )
              else
                const Text(
                  'Locked',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isUnlocked
            ? color.withValues(alpha: 0.08)
            : const Color(0xFF0F172A).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked ? color.withValues(alpha: 0.35) : Colors.white10,
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isUnlocked ? color.withValues(alpha: 0.5) : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Center(
              child: isUnlocked
                  ? Icon(definition.icon, size: 24, color: color)
                  : const Icon(Icons.lock_rounded, color: Colors.white24, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            definition.title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.white : Colors.white54,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: isUnlocked ? color.withValues(alpha: 0.15) : Colors.white10,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${definition.xpReward} XP',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isUnlocked ? color : Colors.white38,
              ),
            ),
          ),
        ],
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
