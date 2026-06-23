import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/challenge_model.dart';
import '../services/challenges_service.dart';

// ─── Challenges Providers ──────────────────────────────────────────

/// Provider for active challenges stream
final activeChallengesProvider = StreamProvider<List<ChallengeModel>>((ref) {
  return ChallengesService.getActiveChallenges();
});

/// Provider for user's challenge progress
final userChallengesProgressProvider = StreamProvider<Map<String, ChallengeProgress>>((ref) {
  return ChallengesService.getUserProgress();
});

/// Provider for available badges
final availableBadgesProvider = StreamProvider<List<BadgeModel>>((ref) {
  return ChallengesService.getAvailableBadges();
});

/// Provider for user's earned badges
final userBadgesProvider = StreamProvider<List<UserBadge>>((ref) {
  return ChallengesService.getUserBadges();
});

/// Combined provider for challenges with progress
final challengesWithProgressProvider = Provider<AsyncValue<List<ChallengeWithProgress>>>((ref) {
  final challengesAsync = ref.watch(activeChallengesProvider);
  final progressAsync = ref.watch(userChallengesProgressProvider);

  return challengesAsync.when(
    data: (challenges) {
      return progressAsync.when(
        data: (progress) {
          final List<ChallengeWithProgress> result = [];
          for (final challenge in challenges) {
            final challengeProgress = progress[challenge.id];
            result.add(ChallengeWithProgress(
              challenge: challenge,
              progress: challengeProgress?.progress ?? 0,
              isCompleted: challengeProgress?.isCompleted ?? false,
              rewardClaimed: challengeProgress?.rewardClaimed ?? false,
            ));
          }
          return AsyncValue.data(result);
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for total earned points from challenges
final totalChallengePointsProvider = Provider<int>((ref) {
  final badgesAsync = ref.watch(userBadgesProvider);
  
  return badgesAsync.when(
    data: (badges) => badges.length * 50, // 50 points per badge
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Provider for new/unseen badges count
final newBadgesCountProvider = Provider<int>((ref) {
  final badgesAsync = ref.watch(userBadgesProvider);
  
  return badgesAsync.when(
    data: (badges) => badges.where((b) => b.isNew).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Challenge service provider for actions
final challengesServiceProvider = Provider<ChallengesServiceActions>((ref) {
  return ChallengesServiceActions(ref);
});

/// Wrapper class for challenge service actions
class ChallengesServiceActions {
  final Ref _ref;
  
  ChallengesServiceActions(this._ref);

  Future<void> updateProgress(String challengeId, int increment) async {
    await ChallengesService.updateProgress(challengeId, increment);
  }

  Future<void> claimReward(String challengeId) async {
    await ChallengesService.claimReward(challengeId);
  }

  Future<void> markBadgeSeen(String badgeId) async {
    await ChallengesService.markBadgeSeen(badgeId);
  }

  Future<void> trackAction(String actionType, {int count = 1}) async {
    await ChallengesService.trackAction(actionType, count: count);
  }

  Future<void> initializeWeeklyChallenges() async {
    await ChallengesService.initializeWeeklyChallenges();
  }
}

/// Helper class combining challenge with user's progress
class ChallengeWithProgress {
  final ChallengeModel challenge;
  final int progress;
  final bool isCompleted;
  final bool rewardClaimed;

  ChallengeWithProgress({
    required this.challenge,
    required this.progress,
    required this.isCompleted,
    required this.rewardClaimed,
  });

  double get progressPercentage => challenge.target > 0 
      ? (progress / challenge.target).clamp(0.0, 1.0) 
      : 0.0;
}
