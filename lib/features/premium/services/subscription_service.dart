import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/models/user_model.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

class SubscriptionService {
  final CollectionReference<Map<String, dynamic>> _usersRef =
      FirebaseService.usersCollection;
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  /// Starts the 1-month free trial for verified status
  Future<void> startTrial(String uid) async {
    final expiryDate = DateTime.now().add(const Duration(days: 30));
    
    // Run as batch or transaction to update user model and record trial logging
    final batch = _firestore.batch();
    
    final userDoc = _usersRef.doc(uid);
    batch.update(userDoc, {
      'subscriptionPlan': 'Premium Trial',
      'subscriptionExpires': Timestamp.fromDate(expiryDate),
      'hasUsedTrial': true,
      'verificationStatus': 'pending',
    });

    final logDoc = _firestore.collection('payments').doc();
    batch.set(logDoc, {
      'id': logDoc.id,
      'uid': uid,
      'planName': 'Premium Trial',
      'amount': 0.0,
      'method': 'free_trial',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'success',
    });

    await batch.commit();
  }

  /// Records a successful premium purchase and sets verification to pending
  Future<void> purchasePremiumPlan({
    required String uid,
    required String planName,
    required double price,
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final expiryDate = DateTime.now().add(const Duration(days: 30));
    
    final batch = _firestore.batch();
    
    final userDoc = _usersRef.doc(uid);
    batch.update(userDoc, {
      'subscriptionPlan': planName,
      'subscriptionExpires': Timestamp.fromDate(expiryDate),
      'verificationStatus': 'pending',
    });

    final logDoc = _firestore.collection('payments').doc();
    batch.set(logDoc, {
      'id': logDoc.id,
      'uid': uid,
      'planName': planName,
      'amount': price,
      'method': 'razorpay',
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'success',
    });

    await batch.commit();
  }

  /// Check user subscription timeline on startup/in settings.
  /// All features are 100% free with unlimited storage and complimentary all-access.
  Future<String> checkSubscriptionTimeline(String uid) async {
    try {
      final userDoc = await _usersRef.doc(uid).get();
      if (!userDoc.exists) return 'active';
      
      final data = userDoc.data();
      final isVerified = data?['isVerified'] as bool? ?? false;
      final plan = data?['subscriptionPlan'] as String? ?? '';
      
      // Auto-grant complimentary verified all-access if not already set
      if (!isVerified || plan.isEmpty) {
        await activateFreeLifetimeAccess(uid);
      }
      return 'active';
    } catch (e) {
      debugPrint('Subscription timeline note: $e');
      return 'active';
    }
  }

  /// Grants 100% complimentary all-access to all features & unlimited storage
  Future<void> activateFreeLifetimeAccess(String uid) async {
    final farFuture = DateTime(2099, 1, 1);
    await _usersRef.doc(uid).update({
      'subscriptionPlan': 'Abyss Platinum',
      'subscriptionExpires': Timestamp.fromDate(farFuture),
      'isVerified': true,
      'verificationStatus': 'verified',
    });
  }

  /// Check if the user subscription is currently active (always true — 100% free)
  bool isSubscriptionActive(UserModel? user) {
    return true;
  }

  /// Listen to the user's verification status in real-time
  Stream<UserModel?> streamUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  // ── TELEGRAM PREMIUM PARITY & GATING (100% UNLOCKED & FREE) ──────────────────

  /// Maximum file upload limit in bytes: Unlimited 10GB for everyone complimentary
  int getMaxUploadLimitBytes(UserModel? user) {
    return 10 * 1024 * 1024 * 1024;
  }

  /// Formatted max upload string
  String getMaxUploadLimitLabel(UserModel? user) {
    return 'Unlimited (100% Free)';
  }

  /// Voice-to-Text transcription access (Free for all)
  bool canTranscribeVoice(UserModel? user) {
    return true;
  }

  /// Priority high-speed download bypass (Free for all)
  bool hasFasterDownloads(UserModel? user) {
    return true;
  }

  /// Max pinned chats limit (100 for all)
  int getMaxPinnedChats(UserModel? user) {
    return 100;
  }

  /// Max joined groups limit (5000 for all)
  int getMaxJoinedGroups(UserModel? user) {
    return 5000;
  }
}
