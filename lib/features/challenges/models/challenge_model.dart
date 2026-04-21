import 'package:cloud_firestore/cloud_firestore.dart';

class ChallengeModel {
  final String id;
  final String title;
  final String description;
  final String type; // 'streak', 'social', 'engagement'
  final int target; // Target value (e.g., 7 days, 10 friends)
  final int reward; // Ripple points or badge unlock
  final String? badgeId; // Badge to unlock if completed
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final Map<String, dynamic> progress; // User's progress

  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.reward,
    this.badgeId,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    required this.progress,
  });

  factory ChallengeModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final startsAt = map['startsAt'] as Timestamp?;
    final endsAt = map['endsAt'] as Timestamp?;
    
    return ChallengeModel(
      id: docId ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? map['name'] as String? ?? 'Challenge',
      description: map['description'] as String? ?? '',
      type: map['type'] as String? ?? 'engagement',
      target: map['target'] as int? ?? 0,
      reward: map['rewardPoints'] as int? ?? map['reward'] as int? ?? 0,
      badgeId: map['rewardBadgeId'] as String? ?? map['badgeId'] as String?,
      startDate: startsAt?.toDate() ?? DateTime.now(),
      endDate: endsAt?.toDate() ?? DateTime.now().add(const Duration(days: 7)),
      isActive: map['isActive'] as bool? ?? true,
      progress: {}, // Progress stored separately
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'target': target,
      'reward': reward,
      'badgeId': badgeId,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
      'progress': progress,
    };
  }

  int get currentProgress {
    switch (type) {
      case 'streak':
        return progress['currentStreak'] as int? ?? 0;
      case 'social':
        return progress['friendsAdded'] as int? ?? 0;
      case 'engagement':
        return progress['messagesSent'] as int? ?? 0;
      default:
        return 0;
    }
  }

  double get progressPercentage => currentProgress / target;
  bool get isCompleted => currentProgress >= target;
}

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String rarity; // 'common', 'rare', 'epic', 'legendary'
  final DateTime? unlockedAt;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.rarity,
    this.unlockedAt,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return BadgeModel(
      id: docId ?? map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Badge',
      description: map['description'] as String? ?? '',
      icon: map['icon'] as String? ?? 'emoji_events',
      rarity: map['rarity'] as String? ?? 'common',
      unlockedAt: (map['unlockedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'rarity': rarity,
      'unlockedAt': unlockedAt,
    };
  }
}

// Predefined weekly challenges
class WeeklyChallenges {
  static List<ChallengeModel> defaultChallenges = [
    ChallengeModel(
      id: 'streak_7_days',
      title: '7-Day Streak Master',
      description: 'Maintain a 7-day streak with any friend',
      type: 'streak',
      target: 7,
      reward: 100,
      badgeId: 'badge_streak_7',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      progress: {'currentStreak': 0},
    ),
    ChallengeModel(
      id: 'social_10_friends',
      title: 'Social Butterfly',
      description: 'Add 10 new friends this week',
      type: 'social',
      target: 10,
      reward: 150,
      badgeId: 'badge_social_10',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      progress: {'friendsAdded': 0},
    ),
    ChallengeModel(
      id: 'engagement_100_msgs',
      title: 'Chatterbox',
      description: 'Send 100 messages this week',
      type: 'engagement',
      target: 100,
      reward: 200,
      badgeId: 'badge_chatterbox',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      progress: {'messagesSent': 0},
    ),
  ];

  static List<BadgeModel> availableBadges = [
    BadgeModel(
      id: 'badge_streak_7',
      name: 'Streak Master',
      description: 'Maintained a 7-day streak',
      icon: '🔥',
      rarity: 'rare',
    ),
    BadgeModel(
      id: 'badge_social_10',
      name: 'Social Butterfly',
      description: 'Added 10 friends in a week',
      icon: '🦋',
      rarity: 'epic',
    ),
    BadgeModel(
      id: 'badge_chatterbox',
      name: 'Chatterbox',
      description: 'Sent 100 messages in a week',
      icon: '💬',
      rarity: 'common',
    ),
    BadgeModel(
      id: 'legendary_ripple',
      name: 'Ripple Legend',
      description: 'Complete all weekly challenges',
      icon: '🌊',
      rarity: 'legendary',
    ),
  ];
}
