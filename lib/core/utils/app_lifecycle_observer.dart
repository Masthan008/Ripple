import 'package:flutter/widgets.dart';

import '../services/presence_service.dart';

/// Watches app lifecycle to update online/offline status via PresenceService.
/// Uses Firebase Realtime Database for instant offline detection.
class AppLifecycleObserver extends WidgetsBindingObserver {
  final String uid;

  AppLifecycleObserver(this.uid);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (uid.isEmpty) return;

    switch (state) {
      case AppLifecycleState.resumed:
        PresenceService.setOnline(uid);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        PresenceService.setOffline(uid);
        break;
    }
  }
}
