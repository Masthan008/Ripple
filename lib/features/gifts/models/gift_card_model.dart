import 'package:cloud_firestore/cloud_firestore.dart';

class GiftCardModel {
  final String id;
  final String title;
  final String description;
  final String theme; // 'birthday', 'anniversary', 'friendship', 'custom'
  final int amount; // Currency amount if applicable
  final String? message;
  final DateTime? expiryDate;
  final bool isRedeemed;
  final DateTime? redeemedAt;

  GiftCardModel({
    required this.id,
    required this.title,
    required this.description,
    required this.theme,
    required this.amount,
    this.message,
    this.expiryDate,
    this.isRedeemed = false,
    this.redeemedAt,
  });

  factory GiftCardModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final expiresAt = map['expiresAt'] as Timestamp?;
    
    return GiftCardModel(
      id: docId ?? map['id'] as String? ?? '',
      title: map['name'] as String? ?? map['title'] as String? ?? 'Gift Card',
      description: map['description'] as String? ?? '',
      theme: map['category'] as String? ?? map['theme'] as String? ?? 'custom',
      amount: map['defaultAmount'] as int? ?? map['amount'] as int? ?? 0,
      message: map['message'] as String?,
      expiryDate: expiresAt?.toDate(),
      isRedeemed: map['isRedeemed'] as bool? ?? false,
      redeemedAt: (map['redeemedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'theme': theme,
      'amount': amount,
      'message': message,
      'expiryDate': expiryDate,
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt,
    };
  }
}

// Predefined gift card themes with glass aesthetics
class GiftCardThemes {
  static List<GiftCardModel> defaultCards = [
    GiftCardModel(
      id: 'gift_birthday_1',
      title: 'Birthday Surprise',
      description: 'A special gift for your birthday',
      theme: 'birthday',
      amount: 100,
    ),
    GiftCardModel(
      id: 'gift_friendship_1',
      title: 'Friendship Token',
      description: 'A token of our friendship',
      theme: 'friendship',
      amount: 50,
    ),
    GiftCardModel(
      id: 'gift_anniversary_1',
      title: 'Anniversary Gift',
      description: 'Celebrating our journey together',
      theme: 'anniversary',
      amount: 200,
    ),
    GiftCardModel(
      id: 'gift_custom_1',
      title: 'Custom Gift',
      description: 'A personalized gift just for you',
      theme: 'custom',
      amount: 150,
    ),
  ];

  static Map<String, Map<String, dynamic>> themeStyles = {
    'birthday': {
      'primaryColor': 0xFFFF6B6B,
      'secondaryColor': 0xFFFFE66D,
      'emoji': '🎂',
      'gradient': [0xFFFF6B6B, 0xFFFFE66D],
    },
    'friendship': {
      'primaryColor': 0xFF4ECDC4,
      'secondaryColor': 0xFF44A08D,
      'emoji': '💝',
      'gradient': [0xFF4ECDC4, 0xFF44A08D],
    },
    'anniversary': {
      'primaryColor': 0xFF667EEA,
      'secondaryColor': 0xFF764BA2,
      'emoji': '💎',
      'gradient': [0xFF667EEA, 0xFF764BA2],
    },
    'custom': {
      'primaryColor': 0xFFA8A8A8,
      'secondaryColor': 0xFFD4D4D4,
      'emoji': '🎁',
      'gradient': [0xFFA8A8A8, 0xFFD4D4D4],
    },
  };
}
