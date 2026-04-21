import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firebase_service.dart';
import '../models/gift_card_model.dart';

/// Service for managing digital gift cards - send, receive, and track
class GiftService {
  static final _fs = FirebaseService.firestore;
  static final _auth = FirebaseService.auth;

  static String? get _uid => _auth.currentUser?.uid;
  static String? get _myName => _auth.currentUser?.displayName ?? 'Someone';

  // ── GIFT CARDS ─────────────────────────────────────────

  /// Get all available gift card themes
  static Stream<List<GiftCardModel>> getAvailableGiftCards() {
    return _fs
        .collection('giftCards')
        .where('isActive', isEqualTo: true)
        .orderBy('category')
        .snapshots()
        .map((snap) => snap.docs.map((d) => GiftCardModel.fromMap(d.data(), d.id)).toList());
  }

  /// Get gifts sent by current user
  static Stream<List<SentGift>> getSentGifts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _fs
        .collection('users')
        .doc(uid)
        .collection('giftsSent')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => SentGift.fromMap(d.data(), d.id)).toList());
  }

  /// Get gifts received by current user
  static Stream<List<ReceivedGift>> getReceivedGifts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _fs
        .collection('users')
        .doc(uid)
        .collection('giftsReceived')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReceivedGift.fromMap(d.data(), d.id)).toList());
  }

  /// Send a gift to another user
  static Future<void> sendGift({
    required String recipientId,
    required String recipientName,
    required String giftCardId,
    required String theme,
    required int amount,
    String? message,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final giftRef = _fs.collection('gifts').doc();
    final giftId = giftRef.id;

    final now = FieldValue.serverTimestamp();

    // Create the gift document
    await giftRef.set({
      'senderId': uid,
      'senderName': _myName,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'giftCardId': giftCardId,
      'theme': theme,
      'amount': amount,
      'message': message ?? '',
      'status': 'pending',
      'sentAt': now,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
    });

    // Add to sender's sent gifts
    await _fs
        .collection('users')
        .doc(uid)
        .collection('giftsSent')
        .doc(giftId)
        .set({
      'giftId': giftId,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'theme': theme,
      'amount': amount,
      'status': 'pending',
      'sentAt': now,
    });

    // Add to recipient's received gifts
    await _fs
        .collection('users')
        .doc(recipientId)
        .collection('giftsReceived')
        .doc(giftId)
        .set({
      'giftId': giftId,
      'senderId': uid,
      'senderName': _myName,
      'theme': theme,
      'amount': amount,
      'message': message ?? '',
      'status': 'pending',
      'isNew': true,
      'receivedAt': now,
    });

    // Send notification to recipient
    try {
      final recipientDoc = await _fs.collection('users').doc(recipientId).get();
      final playerId = recipientDoc.data()?['oneSignalPlayerId'] as String?;
      
      if (playerId != null && playerId.isNotEmpty) {
        // TODO: Send push notification via NotificationService
        // await NotificationService.sendGiftNotification(
        //   recipientPlayerId: playerId,
        //   senderName: _myName ?? 'Someone',
        //   giftTheme: theme,
        // );
      }
    } catch (_) {}

    debugPrint('🎁 Gift sent: $giftId to $recipientName');
  }

  /// Claim a received gift
  static Future<void> claimGift(String giftId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final batch = _fs.batch();

    // Update main gift document
    final giftRef = _fs.collection('gifts').doc(giftId);
    batch.update(giftRef, {
      'status': 'claimed',
      'claimedAt': FieldValue.serverTimestamp(),
    });

    // Update recipient's copy
    final receivedRef = _fs
        .collection('users')
        .doc(uid)
        .collection('giftsReceived')
        .doc(giftId);
    batch.update(receivedRef, {
      'status': 'claimed',
      'isNew': false,
      'claimedAt': FieldValue.serverTimestamp(),
    });

    // Get gift details to update sender's copy
    final giftDoc = await giftRef.get();
    final senderId = giftDoc.data()?['senderId'] as String?;
    
    if (senderId != null) {
      final sentRef = _fs
          .collection('users')
          .doc(senderId)
          .collection('giftsSent')
          .doc(giftId);
      batch.update(sentRef, {
        'status': 'claimed',
      });
    }

    await batch.commit();
    debugPrint('🎁 Gift claimed: $giftId');
  }

  /// Mark gift as viewed (removes "new" indicator)
  static Future<void> markGiftViewed(String giftId) async {
    final uid = _uid;
    if (uid == null) return;

    await _fs
        .collection('users')
        .doc(uid)
        .collection('giftsReceived')
        .doc(giftId)
        .update({'isNew': false});
  }

  /// Delete an expired or unwanted gift
  static Future<void> deleteGift(String giftId, {bool isReceived = true}) async {
    final uid = _uid;
    if (uid == null) return;

    final collection = isReceived ? 'giftsReceived' : 'giftsSent';
    
    await _fs
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(giftId)
        .delete();

    debugPrint('🗑️ Gift deleted: $giftId');
  }

  // ── INITIALIZATION ─────────────────────────────────────

  /// Initialize default gift card themes
  static Future<void> initializeGiftCards() async {
    final existing = await _fs.collection('giftCards').limit(1).get();
    if (existing.docs.isNotEmpty) {
      debugPrint('ℹ️ Gift cards already initialized');
      return;
    }

    final giftCards = [
      {
        'name': 'Friendship Glow',
        'description': 'A warm gift for a dear friend',
        'icon': 'emoji_emotions',
        'colorHex': '0xFF0EA5E9',
        'category': 'friendship',
        'minAmount': 10,
        'maxAmount': 500,
        'isActive': true,
      },
      {
        'name': 'Celebration Burst',
        'description': 'Celebrate special moments together',
        'icon': 'celebration',
        'colorHex': '0xFFA855F7',
        'category': 'celebration',
        'minAmount': 25,
        'maxAmount': 1000,
        'isActive': true,
      },
      {
        'name': 'Love Ripple',
        'description': 'Send love across the distance',
        'icon': 'favorite',
        'colorHex': '0xFFF472B6',
        'category': 'love',
        'minAmount': 20,
        'maxAmount': 750,
        'isActive': true,
      },
      {
        'name': 'Gratitude Flow',
        'description': 'Express your heartfelt thanks',
        'icon': 'volunteer_activism',
        'colorHex': '0xFF34D399',
        'category': 'gratitude',
        'minAmount': 15,
        'maxAmount': 300,
        'isActive': true,
      },
      {
        'name': 'Encouragement Wave',
        'description': 'Lift someone\'s spirits',
        'icon': 'emoji_flags',
        'colorHex': '0xFFFBBF24',
        'category': 'encouragement',
        'minAmount': 10,
        'maxAmount': 250,
        'isActive': true,
      },
    ];

    for (final card in giftCards) {
      await _fs.collection('giftCards').add(card);
    }

    debugPrint('✅ Gift cards initialized');
  }

  /// Get available friends to send gifts to
  static Future<List<Map<String, dynamic>>> getFriends() async {
    final uid = _uid;
    if (uid == null) return [];

    // Get user's chat participants as friends
    final chats = await _fs
        .collection('chats')
        .where('participants', arrayContains: uid)
        .limit(50)
        .get();

    final friendIds = <String>{};
    for (final chat in chats.docs) {
      final participants = chat.data()['participants'] as List<dynamic>? ?? [];
      for (final p in participants) {
        if (p != uid) friendIds.add(p as String);
      }
    }

    if (friendIds.isEmpty) return [];

    // Get friend details
    final friends = <Map<String, dynamic>>[];
    for (final friendId in friendIds.take(20)) {
      final doc = await _fs.collection('users').doc(friendId).get();
      if (doc.exists) {
        final data = doc.data()!;
        friends.add({
          'uid': friendId,
          'name': data['name'] ?? 'Unknown',
          'photoUrl': data['photoUrl'],
        });
      }
    }

    return friends;
  }
}

/// Sent gift model
class SentGift {
  final String id;
  final String giftId;
  final String recipientId;
  final String recipientName;
  final String theme;
  final int amount;
  final String status;
  final DateTime sentAt;

  SentGift({
    required this.id,
    required this.giftId,
    required this.recipientId,
    required this.recipientName,
    required this.theme,
    required this.amount,
    required this.status,
    required this.sentAt,
  });

  factory SentGift.fromMap(Map<String, dynamic> map, String id) {
    return SentGift(
      id: id,
      giftId: map['giftId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      recipientName: map['recipientName'] ?? 'Unknown',
      theme: map['theme'] ?? 'default',
      amount: map['amount'] ?? 0,
      status: map['status'] ?? 'pending',
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Received gift model
class ReceivedGift {
  final String id;
  final String giftId;
  final String senderId;
  final String senderName;
  final String theme;
  final int amount;
  final String? message;
  final String status;
  final bool isNew;
  final DateTime receivedAt;
  final DateTime? claimedAt;

  ReceivedGift({
    required this.id,
    required this.giftId,
    required this.senderId,
    required this.senderName,
    required this.theme,
    required this.amount,
    this.message,
    required this.status,
    this.isNew = false,
    required this.receivedAt,
    this.claimedAt,
  });

  factory ReceivedGift.fromMap(Map<String, dynamic> map, String id) {
    return ReceivedGift(
      id: id,
      giftId: map['giftId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Someone',
      theme: map['theme'] ?? 'default',
      amount: map['amount'] ?? 0,
      message: map['message'] as String?,
      status: map['status'] ?? 'pending',
      isNew: map['isNew'] ?? false,
      receivedAt: (map['receivedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      claimedAt: (map['claimedAt'] as Timestamp?)?.toDate(),
    );
  }
}
