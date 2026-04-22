import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final IconData icon;
  final AchievementTier tier;
  final Timestamp? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
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
      icon: IconData(d['iconCode'] as int? ?? Icons.emoji_events_rounded.codePoint, fontFamily: 'MaterialIcons'),
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
      icon: Icons.waves_rounded,
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'chatterbox',
      title: 'Chatterbox',
      description: 'Send 100 messages',
      icon: Icons.chat_bubble_rounded,
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'mega_messenger',
      title: 'Mega Messenger',
      description: 'Send 1000 messages',
      icon: Icons.mail_rounded,
      tier: AchievementTier.silver,
    ),

    // STREAKS
    AchievementModel(
      id: 'on_fire',
      title: 'On Fire',
      description: 'Reach a 7-day streak',
      icon: Icons.local_fire_department_rounded,
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'unstoppable',
      title: 'Unstoppable',
      description: 'Reach a 30-day streak',
      icon: Icons.diamond_rounded,
      tier: AchievementTier.gold,
    ),
    AchievementModel(
      id: 'legendary',
      title: 'Legendary',
      description: 'Reach a 100-day streak',
      icon: Icons.workspace_premium_rounded,
      tier: AchievementTier.diamond,
    ),

    // SOCIAL
    AchievementModel(
      id: 'friendly',
      title: 'Friendly',
      description: 'Add your first friend',
      icon: Icons.handshake_rounded,
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'social_butterfly',
      title: 'Social Butterfly',
      description: 'Add 10 friends',
      icon: Icons.bug_report_rounded,
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'popular',
      title: 'Popular',
      description: 'Add 50 friends',
      icon: Icons.star_rounded,
      tier: AchievementTier.gold,
    ),

    // MEDIA
    AchievementModel(
      id: 'photographer',
      title: 'Photographer',
      description: 'Send 50 images',
      icon: Icons.camera_alt_rounded,
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'podcaster',
      title: 'Podcaster',
      description: 'Send 20 voice messages',
      icon: Icons.mic_rounded,
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'gif_master',
      title: 'GIF Master',
      description: 'Send 30 GIFs',
      icon: Icons.theater_comedy_rounded,
      tier: AchievementTier.bronze,
    ),

    // AI & FEATURES
    AchievementModel(
      id: 'multilingual',
      title: 'Multilingual',
      description: 'Use translator 5 times',
      icon: Icons.public_rounded,
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'ai_master',
      title: 'AI Master',
      description: 'Use AI features 20 times',
      icon: Icons.smart_toy_rounded,
      tier: AchievementTier.silver,
    ),
    AchievementModel(
      id: 'quick_reply',
      title: 'Quick Reply',
      description: 'Reply within 1 min 10x',
      icon: Icons.bolt_rounded,
      tier: AchievementTier.bronze,
    ),

    // PRIVACY
    AchievementModel(
      id: 'ghost',
      title: 'Ghost',
      description: 'Use stealth mode 7 days',
      icon: Icons.visibility_off_rounded,
      tier: AchievementTier.silver,
    ),

    // PROFILE
    AchievementModel(
      id: 'complete_profile',
      title: 'All Set',
      description: 'Complete your profile',
      icon: Icons.check_circle_rounded,
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'early_adopter',
      title: 'Early Adopter',
      description: 'One of the first Ripple users',
      icon: Icons.rocket_launch_rounded,
      tier: AchievementTier.gold,
    ),

    // GROUPS
    AchievementModel(
      id: 'team_player',
      title: 'Team Player',
      description: 'Join 5 groups',
      icon: Icons.group_rounded,
      tier: AchievementTier.bronze,
    ),
    AchievementModel(
      id: 'group_leader',
      title: 'Group Leader',
      description: 'Create 3 groups',
      icon: Icons.emoji_events_rounded,
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
