import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service — FCM + local notifications
/// Full implementation in Phase 9
class NotificationService {
  NotificationService._();

  static FlutterLocalNotificationsPlugin? _localNotifications;

  /// Initialize notification channels and permissions
  static Future<void> initialize() async {
    try {
      final fcm = FirebaseMessaging.instance;

      // Request permission
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Initialize local notifications
      _localNotifications = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications!.initialize(initSettings);
    } catch (e) {
      debugPrint('⚠️ NotificationService init error: $e');
    }
  }

  /// Get the current FCM token
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('⚠️ FCM getToken error: $e');
      return null;
    }
  }

  /// Listen for token refreshes
  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  /// Show a local notification
  static Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_localNotifications == null) return;

    const androidDetails = AndroidNotificationDetails(
      'ripple_messages',
      'Messages',
      channelDescription: 'Chat message notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications!.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
