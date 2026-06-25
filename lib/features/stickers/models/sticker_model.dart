class StickerModel {
  final String id;
  final String name;
  final String emoji;
  final String? animatedUrl;
  final bool isAnimated;
  final String category;
  final bool isPremium;

  StickerModel({
    required this.id,
    required this.name,
    required this.emoji,
    this.animatedUrl,
    this.isAnimated = false,
    required this.category,
    this.isPremium = false,
  });

  factory StickerModel.fromMap(Map<String, dynamic> map) {
    return StickerModel(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      animatedUrl: map['animatedUrl'] as String?,
      isAnimated: map['isAnimated'] as bool? ?? false,
      category: map['category'] as String,
      isPremium: map['isPremium'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'animatedUrl': animatedUrl,
      'isAnimated': isAnimated,
      'category': category,
      'isPremium': isPremium,
    };
  }
}

class StickerCategory {
  final String id;
  final String name;
  final String icon;
  final bool isLocked;

  StickerCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.isLocked = false,
  });
}

// Predefined Ripple Stickers with glassmorphism aesthetic
class RippleStickers {
  static List<StickerModel> defaultStickers = [
    // ─── Ripple Signature Pack (free, animated) ──────
    StickerModel(
      id: 'ripple_1',
      name: 'Tsunami Pulse',
      emoji: '🌊',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_2',
      name: 'Crystal Shard',
      emoji: '🔷',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_3',
      name: 'Prismatic Flare',
      emoji: '🔆',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_4',
      name: 'Frozen Nova',
      emoji: '❄️',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_5',
      name: 'Cosmic Tear',
      emoji: '💧',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_6',
      name: 'Aurora Bloom',
      emoji: '🌌',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_7',
      name: 'Nebula Heart',
      emoji: '💜',
      category: 'ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_8',
      name: 'Plasma Ring',
      emoji: '🔵',
      category: 'ripple',
      isAnimated: true,
    ),

    // ─── Fun Pack (free) ─────────────────────────────
    StickerModel(
      id: 'fun_1',
      name: 'Dead Laughing',
      emoji: '🤣',
      category: 'fun',
    ),
    StickerModel(
      id: 'fun_2',
      name: 'Inferno',
      emoji: '🔥',
      category: 'fun',
    ),
    StickerModel(
      id: 'fun_3',
      name: 'Skull',
      emoji: '💀',
      category: 'fun',
    ),
    StickerModel(
      id: 'fun_4',
      name: 'Mind Blown',
      emoji: '🤯',
      category: 'fun',
    ),
    StickerModel(
      id: 'fun_5',
      name: 'Clown',
      emoji: '🤡',
      category: 'fun',
    ),
    StickerModel(
      id: 'fun_6',
      name: 'Ghost',
      emoji: '👻',
      category: 'fun',
    ),

    // ─── Mood Pack (free) ────────────────────────────
    StickerModel(
      id: 'mood_1',
      name: 'Chill Vibes',
      emoji: '😌',
      category: 'mood',
    ),
    StickerModel(
      id: 'mood_2',
      name: 'Sheesh',
      emoji: '🥶',
      category: 'mood',
    ),
    StickerModel(
      id: 'mood_3',
      name: 'Cap',
      emoji: '🧢',
      category: 'mood',
    ),
    StickerModel(
      id: 'mood_4',
      name: 'Slay',
      emoji: '💅',
      category: 'mood',
    ),
    StickerModel(
      id: 'mood_5',
      name: 'Nerd',
      emoji: '🤓',
      category: 'mood',
    ),
    StickerModel(
      id: 'mood_6',
      name: 'Sob',
      emoji: '😭',
      category: 'mood',
    ),

    // ─── Premium: Love Pack ─────────────────────────
    StickerModel(
      id: 'love_1',
      name: 'Heart Eyes',
      emoji: '😍',
      category: 'love',
      isPremium: true,
    ),
    StickerModel(
      id: 'love_2',
      name: 'Revolving Hearts',
      emoji: '💞',
      category: 'love',
      isPremium: true,
    ),
    StickerModel(
      id: 'love_3',
      name: 'Smooching',
      emoji: '😘',
      category: 'love',
      isPremium: true,
    ),
    StickerModel(
      id: 'love_4',
      name: 'Melting Face',
      emoji: '🫠',
      category: 'love',
      isPremium: true,
    ),
    StickerModel(
      id: 'love_5',
      name: 'Cupid Arrow',
      emoji: '💘',
      category: 'love',
      isPremium: true,
    ),
    StickerModel(
      id: 'love_6',
      name: 'Love Letter',
      emoji: '💌',
      category: 'love',
      isPremium: true,
    ),

    // ─── Premium: Gaming Pack ───────────────────────
    StickerModel(
      id: 'gaming_1',
      name: 'Controller',
      emoji: '🎮',
      category: 'gaming',
      isPremium: true,
    ),
    StickerModel(
      id: 'gaming_2',
      name: 'Champion',
      emoji: '🏆',
      category: 'gaming',
      isPremium: true,
    ),
    StickerModel(
      id: 'gaming_3',
      name: 'Retro Arcade',
      emoji: '🕹️',
      category: 'gaming',
      isPremium: true,
    ),
    StickerModel(
      id: 'gaming_4',
      name: 'Space Invader',
      emoji: '👾',
      category: 'gaming',
      isPremium: true,
    ),
    StickerModel(
      id: 'gaming_5',
      name: 'Battle Swords',
      emoji: '⚔️',
      category: 'gaming',
      isPremium: true,
    ),
    StickerModel(
      id: 'gaming_6',
      name: 'Bullseye',
      emoji: '🎯',
      category: 'gaming',
      isPremium: true,
    ),

    // ─── Special: NeoGlass Pack (animated) ──────────
    StickerModel(
      id: 'special_1',
      name: 'Aqua Vortex',
      emoji: '🌀',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_2',
      name: 'Neon Jellyfish',
      emoji: '🪼',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_3',
      name: 'Saturn Ring',
      emoji: '🪐',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_4',
      name: 'Thunderbolt',
      emoji: '⚡',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_5',
      name: 'Atomic Core',
      emoji: '⚛️',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_6',
      name: 'Crystal Ball',
      emoji: '🔮',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_7',
      name: 'Diamond Prism',
      emoji: '💎',
      category: 'special',
      isAnimated: true,
    ),
    StickerModel(
      id: 'special_8',
      name: 'Star Burst',
      emoji: '✨',
      category: 'special',
      isAnimated: true,
    ),

    // ─── Premium: Nature Pack ───────────────────────
    StickerModel(
      id: 'nature_1',
      name: 'Cherry Blossom',
      emoji: '🌸',
      category: 'nature',
      isPremium: true,
    ),
    StickerModel(
      id: 'nature_2',
      name: 'Crescent Moon',
      emoji: '🌙',
      category: 'nature',
      isPremium: true,
    ),
    StickerModel(
      id: 'nature_3',
      name: 'Rainbow Arc',
      emoji: '🌈',
      category: 'nature',
      isPremium: true,
    ),
    StickerModel(
      id: 'nature_4',
      name: 'Volcano',
      emoji: '🌋',
      category: 'nature',
      isPremium: true,
    ),
    StickerModel(
      id: 'nature_5',
      name: 'Snowflake',
      emoji: '❄️',
      category: 'nature',
      isPremium: true,
    ),
    StickerModel(
      id: 'nature_6',
      name: 'Shooting Star',
      emoji: '🌠',
      category: 'nature',
      isPremium: true,
    ),
  ];

  static List<StickerCategory> categories = [
    StickerCategory(id: 'ripple', name: 'Ripple', icon: '🌊'),
    StickerCategory(id: 'fun', name: 'Fun', icon: '🔥'),
    StickerCategory(id: 'mood', name: 'Mood', icon: '😌'),
    StickerCategory(id: 'special', name: 'NeoGlass', icon: '💎'),
    StickerCategory(id: 'love', name: 'Love', icon: '💞', isLocked: true),
    StickerCategory(id: 'gaming', name: 'Gaming', icon: '🎮', isLocked: true),
    StickerCategory(id: 'nature', name: 'Nature', icon: '🌸', isLocked: true),
  ];
}
