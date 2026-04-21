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
    StickerModel(
      id: 'ripple_1',
      name: 'Ripple Wave',
      emoji: '🌊',
      category: 'Ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_2',
      name: 'Aqua Heart',
      emoji: '💙',
      category: 'Ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_3',
      name: 'Glass Star',
      emoji: '✨',
      category: 'Ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_4',
      name: 'Bioluminescent',
      emoji: '🔮',
      category: 'Ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'ripple_5',
      name: 'Liquid Drop',
      emoji: '💧',
      category: 'Ripple',
      isAnimated: true,
    ),
    StickerModel(
      id: 'fun_1',
      name: 'Laugh',
      emoji: '😂',
      category: 'Fun',
    ),
    StickerModel(
      id: 'fun_2',
      name: 'Fire',
      emoji: '🔥',
      category: 'Fun',
    ),
    StickerModel(
      id: 'fun_3',
      name: 'Love',
      emoji: '❤️',
      category: 'Fun',
    ),
    StickerModel(
      id: 'fun_4',
      name: 'Cool',
      emoji: '😎',
      category: 'Fun',
    ),
    StickerModel(
      id: 'fun_5',
      name: 'Rocket',
      emoji: '🚀',
      category: 'Fun',
    ),
  ];

  static List<StickerCategory> categories = [
    StickerCategory(id: 'ripple', name: 'Ripple', icon: '🌊'),
    StickerCategory(id: 'fun', name: 'Fun', icon: '😂'),
    StickerCategory(id: 'love', name: 'Love', icon: '❤️', isLocked: true),
    StickerCategory(id: 'gaming', name: 'Gaming', icon: '🎮', isLocked: true),
  ];
}
