import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';

/// Watches app lifecycle to update online/offline status in Firestore
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = FirebaseService.auth.currentUser;
    if (user == null) return;

    final docRef = FirebaseService.firestore.collection('users').doc(user.uid);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground → set online
        docRef.update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }).catchError((_) {});
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background or closed → set offline
        docRef.update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }).catchError((_) {});
        break;
    }
  }
}
