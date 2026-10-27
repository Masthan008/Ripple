import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum AchievementTier {
  bronze,
  silver,
  gold,
  diamond,
}

enum AchievementTrack {
  cipher('Cipher & Security', Icons.lock_outline_rounded),
  network('Network & Social', Icons.hub_outlined),
  media('Media & Audio', Icons.perm_media_outlined),
  chronos('Chronos & Streaks', Icons.timer_outlined),
  multiNode('Multi-Node Sync', Icons.devices_outlined),
  identity('Identity & Prestige', Icons.military_tech_outlined);

  final String label;
  final IconData icon;
  const AchievementTrack(this.label, this.icon);
}

class UserRank {
  final String title;
  final int minXp;
  final int maxXp;
  final Color color;
  final IconData icon;

  const UserRank({
    required this.title,
    required this.minXp,
    required this.maxXp,
    required this.color,
    required this.icon,
  });

  static const List<UserRank> ranks = [
    UserRank(
      title: 'Initiate',
      minXp: 0,
      maxXp: 299,
      color: Color(0xFF94A3B8),
      icon: Icons.shield_outlined,
    ),
    UserRank(
      title: 'Cipher',
      minXp: 300,
      maxXp: 799,
      color: Color(0xFF38BDF8),
      icon: Icons.lock_outline_rounded,
    ),
    UserRank(
      title: 'Sentinel',
      minXp: 800,
      maxXp: 1799,
      color: Color(0xFF10B981),
      icon: Icons.verified_user_rounded,
    ),
    UserRank(
      title: 'Vanguard',
      minXp: 1800,
      maxXp: 3499,
      color: Color(0xFFF59E0B),
      icon: Icons.local_police_rounded,
    ),
    UserRank(
      title: 'Apex Grandmaster',
      minXp: 3500,
      maxXp: 100000,
      color: Color(0xFFA855F7),
      icon: Icons.military_tech_rounded,
    ),
  ];

  static UserRank forXp(int xp) {
    for (final r in ranks.reversed) {
      if (xp >= r.minXp) return r;
    }
    return ranks.first;
  }
}

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementTier tier;
  final AchievementTrack track;
  final int xpReward;
  final Timestamp? unlockedAt;

  const AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    this.track = AchievementTrack.cipher,
    this.xpReward = 100,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  factory AchievementModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final id = d['id'] as String;
    final def = AchievementDefinitions.findById(id);

    return AchievementModel(
      id: id,
      title: def?.title ?? d['title'] as String? ?? 'Achievement',
      description: def?.description ?? d['description'] as String? ?? '',
      icon: def?.icon ?? Icons.emoji_events_rounded,
      tier: AchievementTier.values.firstWhere(
        (t) => t.name == (d['tier'] as String? ?? 'bronze'),
        orElse: () => AchievementTier.bronze,
      ),
      track: def?.track ?? AchievementTrack.cipher,
      xpReward: def?.xpReward ?? (d['xpReward'] as int? ?? 100),
      unlockedAt: d['unlockedAt'] as Timestamp?,
    );
  }
}

/// All 24 Zero-Trace & Security Achievement Definitions
class AchievementDefinitions {
  static const List<AchievementModel> all = [
    // ─── 1. Cipher & Security ──────────────────────────────────────────────
    AchievementModel(
      id: 'cryptographer',
      title: 'Cryptographer',
      description: 'Start your first End-to-End Encrypted secret chat',
      icon: Icons.lock_rounded,
      tier: AchievementTier.bronze,
      track: AchievementTrack.cipher,
      xpReward: 50,
    ),
    AchievementModel(
      id: 'ghost_protocol',
      title: 'Ghost Protocol',
      description: 'Send a self-destructing view-once media message',
      icon: Icons.visibility_off_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.cipher,
      xpReward: 100,
    ),
    AchievementModel(
      id: 'vault_sentinel',
      title: 'Vault Sentinel',
      description: 'Enable biometric App Lock or Passcode protection',
      icon: Icons.security_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.cipher,
      xpReward: 150,
    ),
    AchievementModel(
      id: 'decoy_operator',
      title: 'Decoy Operator',
      description: 'Configure a stealth decoy vault passcode',
      icon: Icons.theater_comedy_rounded,
      tier: AchievementTier.gold,
      track: AchievementTrack.cipher,
      xpReward: 250,
    ),
    AchievementModel(
      id: 'zero_trace_mesh',
      title: 'Zero-Trace Mesh',
      description: 'Exchange an offline peer-to-peer memory message',
      icon: Icons.hub_rounded,
      tier: AchievementTier.diamond,
      track: AchievementTrack.cipher,
      xpReward: 300,
    ),

    // ─── 2. Network & Social ──────────────────────────────────────────────
    AchievementModel(
      id: 'first_handshake',
      title: 'First Handshake',
      description: 'Send your first encrypted direct message',
      icon: Icons.handshake_rounded,
      tier: AchievementTier.bronze,
      track: AchievementTrack.network,
      xpReward: 50,
    ),
    AchievementModel(
      id: 'signal_multiplier',
      title: 'Signal Multiplier',
      description: 'Create a secure group with 5+ verified members',
      icon: Icons.groups_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.network,
      xpReward: 150,
    ),
    AchievementModel(
      id: 'mesh_pioneer',
      title: 'Mesh Pioneer',
      description: 'Connect with 10 peer contacts',
      icon: Icons.person_add_rounded,
      tier: AchievementTier.gold,
      track: AchievementTrack.network,
      xpReward: 250,
    ),
    AchievementModel(
      id: 'network_centurion',
      title: 'Network Centurion',
      description: 'Exchange 1,000 total verified messages',
      icon: Icons.forum_rounded,
      tier: AchievementTier.gold,
      track: AchievementTrack.network,
      xpReward: 500,
    ),
    AchievementModel(
      id: 'matrix_sovereign',
      title: 'Matrix Sovereign',
      description: 'Exchange 10,000 total verified messages',
      icon: Icons.stars_rounded,
      tier: AchievementTier.diamond,
      track: AchievementTrack.network,
      xpReward: 1000,
    ),

    // ─── 3. Media & Audio ──────────────────────────────────────────────────
    AchievementModel(
      id: 'soundwave_artist',
      title: 'Soundwave Artist',
      description: 'Record & send 20 high-fidelity voice notes',
      icon: Icons.mic_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.media,
      xpReward: 100,
    ),
    AchievementModel(
      id: 'visual_archivist',
      title: 'Visual Archivist',
      description: 'Securely share 50 encrypted media documents',
      icon: Icons.perm_media_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.media,
      xpReward: 150,
    ),
    AchievementModel(
      id: 'motion_master',
      title: 'Motion Master',
      description: 'Send 25 animated stickers or reactions',
      icon: Icons.animation_rounded,
      tier: AchievementTier.bronze,
      track: AchievementTrack.media,
      xpReward: 100,
    ),
    AchievementModel(
      id: 'direct_streamer',
      title: 'Direct Streamer',
      description: 'Complete a 15-minute encrypted video call',
      icon: Icons.videocam_rounded,
      tier: AchievementTier.gold,
      track: AchievementTrack.media,
      xpReward: 200,
    ),

    // ─── 4. Chronos & Streaks ──────────────────────────────────────────────
    AchievementModel(
      id: 'streak_spark',
      title: 'Spark',
      description: 'Maintain an active 7-day conversation streak',
      icon: Icons.bolt_rounded,
      tier: AchievementTier.bronze,
      track: AchievementTrack.chronos,
      xpReward: 100,
    ),
    AchievementModel(
      id: 'iron_vanguard',
      title: 'Iron Vanguard',
      description: 'Maintain an active 30-day unbroken streak',
      icon: Icons.shield_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.chronos,
      xpReward: 300,
    ),
    AchievementModel(
      id: 'apex_sentinel',
      title: 'Apex Sentinel',
      description: 'Reach a legendary 100-day unbroken streak',
      icon: Icons.workspace_premium_rounded,
      tier: AchievementTier.diamond,
      track: AchievementTrack.chronos,
      xpReward: 1000,
    ),
    AchievementModel(
      id: 'night_owl',
      title: 'Night Owl',
      description: 'Send a secure message between 1:00 AM and 4:00 AM',
      icon: Icons.bedtime_rounded,
      tier: AchievementTier.bronze,
      track: AchievementTrack.chronos,
      xpReward: 150,
    ),
    AchievementModel(
      id: 'rapid_reflex',
      title: 'Rapid Reflex',
      description: 'Reply to an incoming message within 20 seconds 10x',
      icon: Icons.timer_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.chronos,
      xpReward: 100,
    ),

    // ─── 5. Multi-Node Sync ────────────────────────────────────────────────
    AchievementModel(
      id: 'quantum_bridge',
      title: 'Quantum Bridge',
      description: 'Link your first Ripple Web Companion workstation',
      icon: Icons.devices_rounded,
      tier: AchievementTier.silver,
      track: AchievementTrack.multiNode,
      xpReward: 100,
    ),
    AchievementModel(
      id: 'dual_terminal',
      title: 'Dual Terminal',
      description: 'Maintain 2 active companion sessions simultaneously',
      icon: Icons.computer_rounded,
      tier: AchievementTier.gold,
      track: AchievementTrack.multiNode,
      xpReward: 200,
    ),

    // ─── 6. Identity & Prestige ────────────────────────────────────────────
    AchievementModel(
      id: 'genesis_identity',
      title: 'Genesis Identity',
      description: 'Complete your bio, profile picture, and custom QR key',
      icon: Icons.badge_rounded,
      tier: AchievementTier.bronze,
      track: AchievementTrack.identity,
      xpReward: 50,
    ),
    AchievementModel(
      id: 'prime_citizen',
      title: 'Prime Citizen',
      description: 'Unlock Gold or Abyss Platinum tier status',
      icon: Icons.verified_rounded,
      tier: AchievementTier.gold,
      track: AchievementTrack.identity,
      xpReward: 300,
    ),
    AchievementModel(
      id: 'apex_grandmaster',
      title: 'Apex Grandmaster',
      description: 'Unlock 20+ achievements across all tracks',
      icon: Icons.military_tech_rounded,
      tier: AchievementTier.diamond,
      track: AchievementTrack.identity,
      xpReward: 1500,
    ),
  ];

  static AchievementModel? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static int calculateTotalXp(List<AchievementModel> unlocked) {
    int total = 0;
    for (final u in unlocked) {
      final def = findById(u.id);
      total += def?.xpReward ?? u.xpReward;
    }
    return total;
  }
}
