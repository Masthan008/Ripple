import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/gift_card_model.dart';
import '../services/gift_service.dart';

// ─── Gift Card Providers ─────────────────────────────────────────

/// Provider for available gift card themes
final availableGiftCardsProvider = StreamProvider<List<GiftCardModel>>((ref) {
  return GiftService.getAvailableGiftCards();
});

/// Provider for purchased gift cards in user inventory
final purchasedGiftCardsProvider = StreamProvider<List<GiftCardModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('purchased_gift_cards')
      .orderBy('purchasedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => GiftCardModel.fromMap(d.data(), d.id)).toList());
});

/// Provider for gifts sent by current user
final sentGiftsProvider = StreamProvider<List<SentGift>>((ref) {
  return GiftService.getSentGifts();
});

/// Provider for gifts received by current user
final receivedGiftsProvider = StreamProvider<List<ReceivedGift>>((ref) {
  return GiftService.getReceivedGifts();
});

/// Provider for available friends to send gifts to
final giftFriendsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return GiftService.getFriends();
});

/// Combined provider for gifts with counts
final giftStatsProvider = Provider<AsyncValue<GiftStats>>((ref) {
  final sentAsync = ref.watch(sentGiftsProvider);
  final receivedAsync = ref.watch(receivedGiftsProvider);

  return sentAsync.when(
    data: (sent) {
      return receivedAsync.when(
        data: (received) {
          return AsyncValue.data(GiftStats(
            sentCount: sent.length,
            receivedCount: received.length,
            pendingReceived: received.where((g) => g.status == 'pending').length,
            newGifts: received.where((g) => g.isNew).length,
            totalSentAmount: sent.fold(0, (sum, g) => sum + g.amount),
            totalReceivedAmount: received.fold(0, (sum, g) => sum + g.amount),
          ));
        },
        loading: () => const AsyncValue.loading(),
        error: (err, stack) => AsyncValue.error(err, stack),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// Provider for new gifts count (for badges/notifications)
final newGiftsCountProvider = Provider<int>((ref) {
  final receivedAsync = ref.watch(receivedGiftsProvider);
  
  return receivedAsync.when(
    data: (gifts) => gifts.where((g) => g.isNew).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// Gift service provider for actions
final giftServiceProvider = Provider<GiftServiceActions>((ref) {
  return GiftServiceActions(ref);
});

/// Wrapper class for gift service actions
class GiftServiceActions {
  final Ref _ref;
  
  GiftServiceActions(this._ref);

  Future<void> sendGift({
    required String recipientId,
    required String recipientName,
    required String giftCardId,
    required String theme,
    required int amount,
    String? message,
  }) async {
    await GiftService.sendGift(
      recipientId: recipientId,
      recipientName: recipientName,
      giftCardId: giftCardId,
      theme: theme,
      amount: amount,
      message: message,
    );
  }

  Future<void> claimGift(String giftId) async {
    await GiftService.claimGift(giftId);
  }

  Future<void> markGiftViewed(String giftId) async {
    await GiftService.markGiftViewed(giftId);
  }

  Future<void> deleteGift(String giftId, {bool isReceived = true}) async {
    await GiftService.deleteGift(giftId, isReceived: isReceived);
  }

  Future<void> initializeGiftCards() async {
    await GiftService.initializeGiftCards();
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    return await GiftService.getFriends();
  }
}

/// Gift statistics model
class GiftStats {
  final int sentCount;
  final int receivedCount;
  final int pendingReceived;
  final int newGifts;
  final int totalSentAmount;
  final int totalReceivedAmount;

  GiftStats({
    required this.sentCount,
    required this.receivedCount,
    required this.pendingReceived,
    required this.newGifts,
    required this.totalSentAmount,
    required this.totalReceivedAmount,
  });
}
