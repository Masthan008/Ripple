import 'package:cloud_firestore/cloud_firestore.dart';
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
