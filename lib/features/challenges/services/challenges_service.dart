import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../models/challenge_model.dart';

/// Service for managing community challenges, user progress, and badges
class ChallengesService {
  static final _fs = FirebaseService.firestore;
  static final _auth = FirebaseService.auth;

  static String? get _uid => _auth.currentUser?.uid;

  // ── CHALLENGES ─────────────────────────────────────────

  /// Get all active weekly challenges
  static Stream<List<ChallengeModel>> getActiveChallenges() {
    final now = Timestamp.now();
    return _fs
        .collection('challenges')
        .where('startsAt', isLessThanOrEqualTo: now)
        .where('endsAt', isGreaterThanOrEqualTo: now)
        .where('isActive', isEqualTo: true)
        .orderBy('endsAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChallengeModel.fromMap(d.data(), d.id)).toList());
  }

  /// Get user's progress for all challenges
  static Stream<Map<String, ChallengeProgress>> getUserProgress() {
    final uid = _uid;
    if (uid == null) return Stream.value({});

    return _fs
        .collection('users')
        .doc(uid)
        .collection('challengeProgress')
        .snapshots()
        .map((snap) {
      final Map<String, ChallengeProgress> progress = {};
      for (final doc in snap.docs) {
        progress[doc.id] = ChallengeProgress.fromMap(doc.data());
      }
      return progress;
    });
  }

  /// Update challenge progress
  static Future<void> updateProgress(String challengeId, int increment) async {
    final uid = _uid;
    if (uid == null) return;

    final progressRef = _fs
        .collection('users')
        .doc(uid)
        .collection('challengeProgress')
        .doc(challengeId);

    final doc = await progressRef.get();
    final current = doc.exists ? (doc.data()?['progress'] ?? 0) as int : 0;
    final newProgress = current + increment;

    // Get challenge details to check if completed
    final challengeDoc = await _fs.collection('challenges').doc(challengeId).get();
    final target = challengeDoc.data()?['target'] ?? 0;
    final isCompleted = newProgress >= target;

    await progressRef.set({
      'progress': newProgress,
      'isCompleted': isCompleted,
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // If completed, award badge
    if (isCompleted && !((doc.data()?['isCompleted'] ?? false) as bool)) {
      final badgeId = challengeDoc.data()?['rewardBadgeId'] as String?;
      if (badgeId != null) {
        await awardBadge(badgeId);
      }
    }

    debugPrint('✅ Challenge progress updated: $challengeId = $newProgress');
  }

  /// Claim challenge reward
  static Future<void> claimReward(String challengeId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final progressRef = _fs
        .collection('users')
        .doc(uid)
        .collection('challengeProgress')
        .doc(challengeId);

    await progressRef.update({
      'rewardClaimed': true,
      'rewardClaimedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('🎁 Challenge reward claimed: $challengeId');
  }

  // ── BADGES ─────────────────────────────────────────────

  /// Get all available badges
  static Stream<List<BadgeModel>> getAvailableBadges() {
    return _fs
        .collection('badges')
        .where('isActive', isEqualTo: true)
        .orderBy('rarity', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BadgeModel.fromMap(d.data(), d.id)).toList());
  }

  /// Get user's earned badges
  static Stream<List<UserBadge>> getUserBadges() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _fs
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserBadge.fromMap(d.data(), d.id)).toList());
  }

  /// Award a badge to the user
  static Future<void> awardBadge(String badgeId) async {
    final uid = _uid;
    if (uid == null) return;

    final userBadgeRef = _fs
        .collection('users')
        .doc(uid)
        .collection('badges')
        .doc(badgeId);

    final doc = await userBadgeRef.get();
    if (doc.exists) return; // Already has this badge

    await userBadgeRef.set({
      'badgeId': badgeId,
      'earnedAt': FieldValue.serverTimestamp(),
      'isNew': true,
    });

    debugPrint('🏆 Badge awarded: $badgeId');
  }

  /// Mark badge as seen (remove "new" indicator)
  static Future<void> markBadgeSeen(String badgeId) async {
    final uid = _uid;
    if (uid == null) return;

    await _fs
        .collection('users')
        .doc(uid)
        .collection('badges')
        .doc(badgeId)
        .update({'isNew': false});
  }

  // ── INITIALIZATION ─────────────────────────────────────

  /// Initialize default challenges (call once at app startup or weekly)
  static Future<void> initializeWeeklyChallenges() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final existing = await _fs
        .collection('challenges')
        .where('startsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('startsAt', isLessThan: Timestamp.fromDate(weekEnd))
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      debugPrint('ℹ️ Weekly challenges already exist');
      return;
    }

    // Default weekly challenges
    final challenges = [
      {
        'title': 'Message Master',
        'description': 'Send 50 messages this week',
        'icon': 'chat',
        'target': 50,
        'startsAt': Timestamp.fromDate(weekStart),
        'endsAt': Timestamp.fromDate(weekEnd),
        'isActive': true,
        'rewardPoints': 100,
        'rewardBadgeId': 'message_master',
      },
      {
        'title': 'Social Butterfly',
        'description': 'Start 3 new conversations',
        'icon': 'group',
        'target': 3,
        'startsAt': Timestamp.fromDate(weekStart),
        'endsAt': Timestamp.fromDate(weekEnd),
        'isActive': true,
        'rewardPoints': 150,
        'rewardBadgeId': 'social_butterfly',
      },
      {
        'title': 'Media Sharer',
        'description': 'Share 10 photos or videos',
        'icon': 'photo',
        'target': 10,
        'startsAt': Timestamp.fromDate(weekStart),
        'endsAt': Timestamp.fromDate(weekEnd),
        'isActive': true,
        'rewardPoints': 75,
        'rewardBadgeId': 'media_sharer',
      },
      {
        'title': 'Voice Note Pro',
        'description': 'Send 5 voice messages',
        'icon': 'mic',
        'target': 5,
        'startsAt': Timestamp.fromDate(weekStart),
        'endsAt': Timestamp.fromDate(weekEnd),
        'isActive': true,
        'rewardPoints': 100,
        'rewardBadgeId': 'voice_pro',
      },
    ];

    for (final challenge in challenges) {
      await _fs.collection('challenges').add(challenge);
    }

    // Initialize default badges if not exist
    await _initializeBadges();

    debugPrint('✅ Weekly challenges initialized');
  }

  static Future<void> _initializeBadges() async {
    final badges = [
      {
        'name': 'Message Master',
        'description': 'Sent 50 messages in a week',
        'icon': 'chat_bubble',
        'rarity': 'common',
        'color': '0xFF0EA5E9',
        'isActive': true,
      },
      {
        'name': 'Social Butterfly',
        'description': 'Started 3 new conversations',
        'icon': 'group',
        'rarity': 'rare',
        'color': '0xFFA855F7',
        'isActive': true,
      },
      {
        'name': 'Media Sharer',
        'description': 'Shared 10 media files',
        'icon': 'photo',
        'rarity': 'common',
        'color': '0xFF22D3EE',
        'isActive': true,
      },
      {
        'name': 'Voice Pro',
        'description': 'Sent 5 voice messages',
        'icon': 'mic',
        'rarity': 'common',
        'color': '0xFFF472B6',
        'isActive': true,
      },
    ];

    for (final badge in badges) {
      final existing = await _fs
          .collection('badges')
          .where('name', isEqualTo: badge['name'])
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await _fs.collection('badges').add(badge);
      }
    }

    debugPrint('✅ Badges initialized');
  }

  /// Track user action for challenge progress
  static Future<void> trackAction(String actionType, {int count = 1}) async {
    // Map actions to challenge types
    final challengeMapping = {
      'message_sent': 'Message Master',
      'new_conversation': 'Social Butterfly',
      'media_shared': 'Media Sharer',
      'voice_sent': 'Voice Note Pro',
    };

    final challengeTitle = challengeMapping[actionType];
    if (challengeTitle == null) return;

    // Find active challenge by title
    final challenges = await _fs
        .collection('challenges')
        .where('title', isEqualTo: challengeTitle)
        .where('isActive', isEqualTo: true)
        .where('endsAt', isGreaterThanOrEqualTo: Timestamp.now())
        .limit(1)
        .get();

    if (challenges.docs.isNotEmpty) {
      final challengeId = challenges.docs.first.id;
      await updateProgress(challengeId, count);
    }
  }
}

/// Challenge progress model
class ChallengeProgress {
  final int progress;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool rewardClaimed;
  final DateTime? rewardClaimedAt;

  ChallengeProgress({
    required this.progress,
    required this.isCompleted,
    this.completedAt,
    this.rewardClaimed = false,
    this.rewardClaimedAt,
  });

  factory ChallengeProgress.fromMap(Map<String, dynamic> map) {
    return ChallengeProgress(
      progress: map['progress'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      rewardClaimed: map['rewardClaimed'] ?? false,
      rewardClaimedAt: (map['rewardClaimedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// User badge model
class UserBadge {
  final String id;
  final String badgeId;
  final DateTime earnedAt;
  final bool isNew;

  UserBadge({
    required this.id,
    required this.badgeId,
    required this.earnedAt,
    this.isNew = false,
  });

  factory UserBadge.fromMap(Map<String, dynamic> map, String id) {
    return UserBadge(
      id: id,
      badgeId: map['badgeId'] ?? '',
      earnedAt: (map['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isNew: map['isNew'] ?? false,
    );
  }
}
