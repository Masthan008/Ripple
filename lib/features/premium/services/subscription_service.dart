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

  /// Check user subscription timeline on startup/in settings and auto-expire if past the end date.
  /// Returns a status string: 'expired', 'expiring_soon', 'active', or 'none'.
  Future<String> checkSubscriptionTimeline(String uid) async {
    try {
      final userDoc = await _usersRef.doc(uid).get();
      if (!userDoc.exists) return 'none';
      
      final data = userDoc.data();
      if (data == null) return 'none';

      final subscriptionPlan = data['subscriptionPlan'] as String?;
      final subscriptionExpires = data['subscriptionExpires'] as Timestamp?;
      final isVerified = data['isVerified'] as bool? ?? false;
      final verificationStatus = data['verificationStatus'] as String? ?? 'none';

      if (subscriptionPlan == null || subscriptionPlan.isEmpty || subscriptionExpires == null) {
        return 'none';
      }

      final expiryDate = subscriptionExpires.toDate();
      final now = DateTime.now();

      if (now.isAfter(expiryDate)) {
        // Revert to unverified status if it was active
        if (isVerified || verificationStatus != 'none') {
          await _usersRef.doc(uid).update({
            'isVerified': false,
            'verificationStatus': 'none',
            'subscriptionPlan': '',
          });
          return 'expired';
        }
        return 'none';
      }

      final difference = expiryDate.difference(now);
      if (difference.inDays <= 3) {
        return 'expiring_soon';
      }

      return 'active';
    } catch (e) {
      debugPrint('Error checking subscription timeline: $e');
      return 'none';
    }
  }

  /// Check if the user subscription is currently active
  bool isSubscriptionActive(UserModel? user) {
    if (user == null) return false;
    if (user.subscriptionPlan == null || user.subscriptionPlan!.isEmpty) return false;
    if (user.subscriptionExpires == null) return false;
    return user.subscriptionExpires!.isAfter(DateTime.now());
  }

  /// Listen to the user's verification status in real-time
  Stream<UserModel?> streamUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }
}
