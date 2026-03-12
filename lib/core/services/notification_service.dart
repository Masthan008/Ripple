import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../features/calls/screens/incoming_call_screen.dart';
import '../utils/env.dart';
import 'firebase_service.dart';

/// Global navigator key — used to push screens from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Notification service — OneSignal push notifications
///
/// OneSignal handles ALL notification display automatically
/// including foreground notifications on Android 13+.
/// No flutter_local_notifications needed.
class NotificationService {
  NotificationService._();

  static const _oneSignalBaseUrl =
      'https://onesignal.com/api/v1/notifications';
  static final Dio _dio = Dio();

  // ─── Initialization ─────────────────────────────────────

  /// Initialize notification service.
  /// OneSignal is already initialized in main.dart before runApp().
  static Future<void> initialize() async {
    // OneSignal handles everything — no local notification setup needed
    debugPrint('🔔 NotificationService initialized (OneSignal-only mode)');
  }

  // ─── OneSignal Player ID Sync ───────────────────────────

  /// Save OneSignal player ID to user's Firestore document.
  /// Call this after user signs in and OneSignal is initialized.
  static Future<void> syncPlayerId(String uid) async {
    try {
      debugPrint('🔔 Starting OneSignal player ID sync for uid: $uid');

      // First check if already opted in
      final isOptedIn =
          OneSignal.User.pushSubscription.optedIn ?? false;
      debugPrint('🔔 OneSignal optedIn: $isOptedIn');

      if (!isOptedIn) {
        // Request permission again if not opted in
        await OneSignal.Notifications.requestPermission(true);
        // Wait for permission response
        await Future.delayed(const Duration(seconds: 3));
      }

      // Try to get player ID with extended retry
      String? playerId = OneSignal.User.pushSubscription.id;
      debugPrint('🔔 Initial player ID: $playerId');

      int attempts = 0;
      while ((playerId == null || playerId.isEmpty) && attempts < 15) {
        await Future.delayed(const Duration(seconds: 3));
        playerId = OneSignal.User.pushSubscription.id;
        attempts++;
        debugPrint('🔔 Attempt $attempts: $playerId');
      }

      if (playerId != null && playerId.isNotEmpty) {
        await FirebaseService.firestore.collection('users').doc(uid).set({
          'oneSignalPlayerId': playerId,
        }, SetOptions(merge: true));
        debugPrint('✅ Player ID saved: $playerId');
      } else {
        debugPrint('❌ Could not get player ID after 15 attempts');
      }

      // Always set up observer for future changes
      _setupSubscriptionObserver(uid);
    } catch (e) {
      debugPrint('⚠️ syncPlayerId error: $e');
    }
  }

  static void _setupSubscriptionObserver(String uid) {
    OneSignal.User.pushSubscription.addObserver((state) async {
      final newId = state.current.id;
      final optedIn = state.current.optedIn;
      debugPrint(
          '📱 Subscription state changed: id=$newId, optedIn=$optedIn');

      if (newId != null && newId.isNotEmpty) {
        await FirebaseService.firestore.collection('users').doc(uid).set({
          'oneSignalPlayerId': newId,
        }, SetOptions(merge: true));
        debugPrint('✅ Player ID saved from observer: $newId');
      }
    });
  }

  // ─── Notification Tap Handlers ──────────────────────────

  /// Setup notification tap handlers for navigation
  static void setupNotificationHandlers(BuildContext context) {
    final router = GoRouter.of(context);

    // OneSignal notification opened handler
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData ?? {};
      _handleNotificationNavigation(router, data);
    });
  }

  static void _handleNotificationNavigation(
      GoRouter router, Map<String, dynamic> data) {
    final type = data['type'];
    switch (type) {
      case 'chat':
        final chatId = data['chatId'] as String?;
        var partnerUid = data['partnerUid'] as String? ?? '';
        final partnerName = data['partnerName'] as String? ?? 'Chat';

        // Fallback: derive partnerUid from chatId (format: uid1_uid2)
        if (partnerUid.isEmpty && chatId != null && chatId.contains('_')) {
          final currentUid =
              FirebaseService.auth.currentUser?.uid ?? '';
          final parts = chatId.split('_');
          partnerUid = parts[0] == currentUid
              ? (parts.length > 1 ? parts[1] : '')
              : parts[0];
        }

        if (chatId != null && chatId.isNotEmpty && partnerUid.isNotEmpty) {
          router.push(
            '/chat?chatId=$chatId'
            '&partnerUid=$partnerUid'
            '&partnerName=${Uri.encodeComponent(partnerName)}',
          );
        } else {
          router.go('/home');
        }
        break;
      case 'group':
        final groupId = data['groupId'] as String?;
        final groupName = data['groupName'] as String? ?? 'Group';
        if (groupId != null && groupId.isNotEmpty) {
          router.push(
            '/group-chat?groupId=$groupId'
            '&groupName=${Uri.encodeComponent(groupName)}',
          );
        } else {
          router.go('/home');
        }
        break;
      case 'friend_request':
        router.push('/requests');
        break;
      case 'call':
        final callId = data['callId'] as String? ?? '';
        final channelName = data['channelName'] as String? ?? '';
        final callerName = data['callerName'] as String? ?? 'Unknown';
        final callerUserId = data['callerUserId'] as String? ?? '';
        final callType = data['callType'] as String? ?? 'audio';
        if (callId.isNotEmpty && channelName.isNotEmpty) {
          // Navigate using a global navigator key to push the incoming call screen
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: callId,
              channelName: channelName,
              callerName: callerName,
              callerUserId: callerUserId,
              isVideo: callType == 'video',
            ),
          ));
        } else {
          router.go('/home');
        }
        break;
      default:
        // Unknown notification type — go home
        router.go('/home');
        break;
    }
  }

  // ─── Send Notifications via OneSignal REST API ──────────

  /// Send a 1-to-1 chat message notification
  static Future<void> sendMessageNotification({
    required String recipientPlayerId,
    required String senderName,
    required String messageText,
    required String chatId,
    String senderUid = '',
  }) async {
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: senderName,
      body: messageText,
      data: {
        'type': 'chat',
        'chatId': chatId,
        'partnerUid': senderUid,
        'partnerName': senderName,
      },
    );
  }

  /// Send a group chat message notification to all members
  static Future<void> sendGroupMessageNotification({
    required List<String> recipientPlayerIds,
    required String senderName,
    required String groupName,
    required String messageText,
    required String groupId,
  }) async {
    if (recipientPlayerIds.isEmpty) return;
    await _sendOneSignalNotification(
      playerIds: recipientPlayerIds,
      title: groupName,
      body: '$senderName: $messageText',
      data: {'type': 'group', 'groupId': groupId},
    );
  }

  /// Send a friend request notification
  static Future<void> sendFriendRequestNotification({
    required String recipientPlayerId,
    required String senderName,
  }) async {
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: 'New Friend Request 👋',
      body: '$senderName wants to connect with you',
      data: {'type': 'friend_request'},
    );
  }

  /// Send a call notification
  static Future<void> sendCallNotification({
    required String recipientPlayerId,
    required String callerName,
    required String callerUserId,
    required String callId,
    required String channelName,
    required String callType,
    required bool isGroup,
  }) async {
    final title = callType == 'video'
        ? '📹 Incoming Video Call'
        : '📞 Incoming Voice Call';
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: title,
      body: '$callerName is calling you',
      data: {
        'type': 'call',
        'callId': callId,
        'channelName': channelName,
        'callerName': callerName,
        'callerUserId': callerUserId,
        'callType': callType,
        'isGroup': isGroup.toString(),
      },
      ttl: 30,
    );
  }

  // ─── Internal ───────────────────────────────────────────

  static Future<void> _sendOneSignalNotification({
    required List<String> playerIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int? ttl,
  }) async {
    final appId = Env.oneSignalAppId;
    final restKey = Env.oneSignalRestApiKey;

    // Debug logging for key validation
    debugPrint(
        '🔑 OneSignal App ID: ${appId.isEmpty ? "MISSING" : "${appId.substring(0, 8)}..."}');
    debugPrint(
        '🔑 REST Key: ${restKey.isEmpty ? "MISSING" : "${restKey.substring(0, 12)}..."}');

    if (appId.isEmpty || restKey.isEmpty || restKey.contains('your_')) {
      debugPrint('❌ Configure ONESIGNAL_REST_API_KEY in .env file!');
      debugPrint(
          '   OneSignal Dashboard → Settings → Keys & IDs → REST API Key');
      return;
    }
    if (playerIds.isEmpty) {
      debugPrint('⚠️ ONESIGNAL: No player IDs to send to');
      return;
    }

    try {
      debugPrint(
          '📤 Sending OneSignal notification to ${playerIds.length} user(s): $title');
      final response = await _dio.post(
        _oneSignalBaseUrl,
        options: Options(headers: {
          'Authorization': 'Basic $restKey',
          'Content-Type': 'application/json',
        }),
        data: {
          'app_id': appId,
          'include_player_ids': playerIds,
          'headings': {'en': title},
          'contents': {'en': body},
          if (data != null) 'data': data,
          'priority': 10,
          if (ttl != null) 'ttl': ttl,
        },
      );
      debugPrint(
          '✅ OneSignal response: ${response.statusCode} ${response.data}');
    } catch (e) {
      debugPrint('❌ OneSignal notification FAILED: $e');
    }
  }
}
