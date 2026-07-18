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

  /// Track which chat the user is currently viewing.
  /// Set by ChatScreen/GroupChatScreen to suppress foreground notifications.
  static String? currentActiveChatId;

  // ─── Initialization ─────────────────────────────────────

  /// Initialize notification service.
  /// OneSignal is already initialized in main.dart before runApp().
  static Future<void> initialize() async {
    debugPrint('🔔 NotificationService initialized globally (OneSignal-only mode)');

    // 1. OneSignal notification opened handler (runs globally at launch)
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData ?? {};
      debugPrint('🔔 Notification clicked with data: $data');
      _handleGlobalNavigation(data);
    });

    // 2. Foreground will display listener (suppression logic)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
      final data = event.notification.additionalData ?? {};
      final type = data['type'] as String?;
      final incomingChatId =
          data['chatId'] as String? ?? data['groupId'] as String?;

      if ((type == 'chat' || type == 'group') &&
          currentActiveChatId != null &&
          incomingChatId == currentActiveChatId) {
        event.preventDefault();
        debugPrint(
            '🔕 Suppressed foreground notification for active chat: $incomingChatId');
        return;
      }

      if (incomingChatId != null && await _isChatMuted(incomingChatId)) {
        event.preventDefault();
        debugPrint(
            '🔕 Suppressed foreground notification for muted chat: $incomingChatId');
      }
    });
  }

  static void _handleGlobalNavigation(Map<String, dynamic> data) {
    final context = navigatorKey.currentState?.context;
    if (context == null) {
      debugPrint('⚠️ Navigator context is null. Retrying notification navigation in 500ms...');
      Future.delayed(const Duration(milliseconds: 500), () => _handleGlobalNavigation(data));
      return;
    }
    
    try {
      final router = GoRouter.of(context);
      _handleNotificationNavigation(router, data);
    } catch (e) {
      debugPrint('⚠️ Failed to resolve GoRouter from context: $e. Retrying in 500ms...');
      Future.delayed(const Duration(milliseconds: 500), () => _handleGlobalNavigation(data));
    }
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
  /// [Deprecated] Handlers are now initialized globally inside [initialize].
  static void setupNotificationHandlers(BuildContext context) {
    debugPrint('🔔 setupNotificationHandlers called (no-op, already initialized globally)');
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
      case 'status_reaction':
        // Navigate to home (status is a sub-tab at index 3)
        router.go('/home');
        break;
      case 'missed_call':
        router.go('/home');
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
    String senderPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: senderName,
      body: messageText,
      largeIcon: senderPhotoUrl,
      androidChannelId: 'ripple_messages',
      sound: sound,
      vibration: vibration,
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
    String groupPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    if (recipientPlayerIds.isEmpty) return;
    await _sendOneSignalNotification(
      playerIds: recipientPlayerIds,
      title: groupName,
      body: '$senderName: $messageText',
      largeIcon: groupPhotoUrl,
      androidChannelId: 'ripple_groups',
      sound: sound,
      vibration: vibration,
      data: {'type': 'group', 'groupId': groupId},
    );
  }

  /// Send a friend request notification
  static Future<void> sendFriendRequestNotification({
    required String recipientPlayerId,
    required String senderName,
    String senderPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: 'New Friend Request 👋',
      body: '$senderName wants to connect with you',
      largeIcon: senderPhotoUrl,
      androidChannelId: 'ripple_social',
      sound: sound,
      vibration: vibration,
      data: {'type': 'friend_request'},
    );
  }

  /// Send a status reaction notification
  static Future<void> sendStatusReactionNotification({
    required String recipientPlayerId,
    required String reactorName,
    required String emoji,
    String reactorPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: 'Status Reaction',
      body: '$reactorName reacted $emoji to your status',
      largeIcon: reactorPhotoUrl,
      androidChannelId: 'ripple_social',
      sound: sound,
      vibration: vibration,
      data: {'type': 'status_reaction'},
    );
  }

  /// Send a call notification with high-priority Android channel
  static Future<void> sendCallNotification({
    required String recipientPlayerId,
    required String callerName,
    required String callerUserId,
    required String callId,
    required String channelName,
    required String callType,
    required bool isGroup,
    String callerPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    final title = callType == 'video'
        ? '📹 Incoming Video Call'
        : '📞 Incoming Voice Call';
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: title,
      body: '$callerName is calling you',
      largeIcon: callerPhotoUrl,
      androidChannelId: 'ripple_calls',
      sound: sound,
      vibration: vibration,
      data: {
        'type': 'call',
        'callId': callId,
        'channelName': channelName,
        'callerName': callerName,
        'callerUserId': callerUserId,
        'callType': callType,
        'isGroup': isGroup.toString(),
      },
      ttl: 60,
    );
  }

  /// Send a missed call notification
  static Future<void> sendMissedCallNotification({
    required String recipientPlayerId,
    required String callerName,
    required String callType,
    String callerPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    final title = 'Missed Call 📞';
    final body = 'You missed a $callType call from $callerName';
    await _sendOneSignalNotification(
      playerIds: [recipientPlayerId],
      title: title,
      body: body,
      largeIcon: callerPhotoUrl,
      androidChannelId: 'ripple_calls',
      sound: sound,
      vibration: vibration,
      data: {
        'type': 'missed_call',
      },
    );
  }

  // ─── Internal ───────────────────────────────────────────

  static Future<void> _sendOneSignalNotification({
    required List<String> playerIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int? ttl,
    String? androidChannelId,
    String? largeIcon,
    bool sound = true,
    bool vibration = true,
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

      final Map<String, dynamic> payload = {
        'app_id': appId,
        'include_player_ids': playerIds,
        'headings': {'en': title},
        'contents': {'en': body},
        'small_icon': 'ic_stat_notification',
        'priority': 10,
      };
      if (largeIcon != null && largeIcon.isNotEmpty) payload['large_icon'] = largeIcon;
      if (data != null) payload['data'] = data;
      if (ttl != null) payload['ttl'] = ttl;
      if (androidChannelId != null) payload['android_channel_id'] = androidChannelId;
      if (!sound) {
        payload['ios_sound'] = 'nil';
        payload['android_sound'] = 'nil';
      }
      if (!vibration) payload['ios_badgeType'] = 'None';

      final response = await _dio.post(
        _oneSignalBaseUrl,
        options: Options(headers: {
          'Authorization': 'Basic $restKey',
          'Content-Type': 'application/json',
        }),
        data: payload,
      );
      debugPrint(
          '✅ OneSignal response: ${response.statusCode} ${response.data}');
    } catch (e) {
      debugPrint('❌ OneSignal notification FAILED: $e');
    }
  }

  static Future<bool> _isChatMuted(String? chatId) async {
    if (chatId == null || chatId.isEmpty) return false;
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return false;

      final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
      final muted = Map<String, dynamic>.from(doc.data()?['mutedChats'] as Map? ?? {});
      if (!muted.containsKey(chatId)) return false;

      final expiryStr = muted[chatId] as String?;
      if (expiryStr == 'always') return true;
      if (expiryStr != null) {
        final expiry = DateTime.tryParse(expiryStr);
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> showMuteDialog(BuildContext context, String chatId, {VoidCallback? onDone}) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mute Notifications',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Other participants will not see that you muted this chat.',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('8 Hours', style: TextStyle(color: Colors.white)),
                onTap: () => _applyMute(ctx, chatId, '8_hours', onDone),
              ),
              ListTile(
                title: const Text('1 Week', style: TextStyle(color: Colors.white)),
                onTap: () => _applyMute(ctx, chatId, '1_week', onDone),
              ),
              ListTile(
                title: const Text('Always', style: TextStyle(color: Colors.white)),
                onTap: () => _applyMute(ctx, chatId, 'always', onDone),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _applyMute(BuildContext context, String chatId, String duration, VoidCallback? onDone) async {
    Navigator.pop(context);
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    final expiry = duration == '8_hours'
        ? DateTime.now().add(const Duration(hours: 8)).toIso8601String()
        : duration == '1_week'
            ? DateTime.now().add(const Duration(days: 7)).toIso8601String()
            : 'always';

    await FirebaseService.firestore.collection('users').doc(uid).set({
      'mutedChats': {chatId: expiry}
    }, SetOptions(merge: true));

    if (onDone != null) onDone();
  }

  static Future<void> unmuteChat(String chatId, {VoidCallback? onDone}) async {
    final uid = FirebaseService.auth.currentUser?.uid;
    if (uid == null) return;

    await FirebaseService.firestore.collection('users').doc(uid).update({
      'mutedChats.$chatId': FieldValue.delete()
    });

    if (onDone != null) onDone();
  }
}
