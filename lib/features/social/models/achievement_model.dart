import 'package:cloud_firestore/cloud_firestore.dart';

enum AchievementTier {
  bronze,
  silver,
  gold,
  diamond,
}

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final AchievementTier tier;
  final Timestamp? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.tier,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  factory AchievementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AchievementModel(
      id: d['id'] as String,
      title: d['title'] as String,
      description: d['description'] as String? ?? '',
      emoji: d['emoji'] as String,
      tier: AchievementTier.values.firstWhere(
        (t) => t.name == (d['tier'] as String? ?? 'bronze'),
        orElse: () => AchievementTier.bronze,
      ),
      unlockedAt: d['unlockedAt'] as Timestamp?,
    );
  }
}

// All achievement definitions
class AchievementDefinitions {
  static const all = [
    // MESSAGING
    AchievementModel(
      id: 'first_wave',
      title: 'First Wave',
      description: 'Send your first message',
      emoji: '🌊',
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'chatterbox',
      title: 'Chatterbox',
      description: 'Send 100 messages',
      emoji: '💬',
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'mega_messenger',
      title: 'Mega Messenger',
      description: 'Send 1000 messages',
      emoji: '📨',
      tier: AchievementTier.silver,
    ),

    // STREAKS
    AchievementModel(
      id: 'on_fire',
      title: 'On Fire',
      description: 'Reach a 7-day streak',
      emoji: '🔥',
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'unstoppable',
      title: 'Unstoppable',
      description: 'Reach a 30-day streak',
      emoji: '💎',
      tier: AchievementTier.gold,
    ),
    AchievementModel(
      id: 'legendary',
      title: 'Legendary',
      description: 'Reach a 100-day streak',
      emoji: '👑',
      tier: AchievementTier.diamond,
    ),

    // SOCIAL
    AchievementModel(
      id: 'friendly',
      title: 'Friendly',
      description: 'Add your first friend',
      emoji: '🤝',
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Add 10 friends',
      emoji: '🦋',
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'popular',
      title: 'Popular',
      description: 'Add 50 friends',
      emoji: '⭐',
      tier: AchievementTier.gold,
    ),

    // MEDIA
    AchievementModel(
      id: 'photographer',
      title: 'Photographer',
      description: 'Send 50 images',
      emoji: '📸',
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'podcaster',
      title: 'Podcaster',
      description: 'Send 20 voice messages',
      emoji: '🎙️',
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'gif_master',
      title: 'GIF Master',
      description: 'Send 30 GIFs',
      emoji: '🎭',
      tier: AchievementTier.bronze,
    ),

    // AI & FEATURES
    AchievementModel(
      id: 'multilingual',
      title: 'Multilingual',
      description: 'Use translator 5 times',
      emoji: '🌍',
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'ai_master',
      title: 'AI Master',
      description: 'Use AI features 20 times',
      emoji: '🤖',
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'quick_reply',
      title: 'Quick Reply',
      description: 'Reply within 1 min 10x',
      emoji: '⚡',
      tier: AchievementTier.bronze,
    ),

    // PRIVACY
    AchievementModel(
      id: 'ghost',
      title: 'Ghost',
      description: 'Use stealth mode 7 days',
      emoji: '👻',
      tier: AchievementTier.silver,
    ),

    // PROFILE
    AchievementModel(
      id: 'complete_profile',
      title: 'All Set',
      description: 'Complete your profile',
      emoji: '✅',
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'early_adopter',
      title: 'Early Adopter',
      description: 'One of the first Ripple users',
      emoji: '🚀',
      tier: AchievementTier.gold,
    ),

    // GROUPS
    AchievementModel(
      id: 'team_player',
      title: 'Team Player',
      description: 'Join 5 groups',
      emoji: '👥',
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'group_leader',
      title: 'Group Leader',
      description: 'Create 3 groups',
      emoji: '🏆',
      tier: AchievementTier.silver,
    ),
  ];

  static AchievementModel? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
