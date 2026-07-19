import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../../features/profile/services/custom_sound_service.dart';

import '../../features/calls/screens/incoming_call_screen.dart';
import '../utils/env.dart';
import 'firebase_service.dart';

/// Global navigator key — used to push screens from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Notification service — OneSignal push notifications
class NotificationService {
  NotificationService._();

  static const _oneSignalBaseUrl =
      'https://onesignal.com/api/v1/notifications';
  static final Dio _dio = Dio();
  static final AudioPlayer _inAppPlayer = AudioPlayer();

  /// Track which chat the user is currently viewing.
  /// Set by ChatScreen/GroupChatScreen to suppress foreground notifications.
  static String? currentActiveChatId;

  // ─── Initialization ─────────────────────────────────────

  /// Initialize notification service.
  /// OneSignal is already initialized in main.dart before runApp().
  static Future<void> initialize() async {
    debugPrint('🔔 NotificationService initialized globally (OneSignal mode)');

    // 1. OneSignal notification opened handler (runs globally at launch)
    OneSignal.Notifications.addClickListener((event) async {
      final actionId = event.result.actionId;
      final data = event.notification.additionalData ?? {};
      debugPrint('🔔 Notification clicked. ActionId: $actionId, Data: $data');

      if (actionId == 'read') {
        final chatId = data['chatId'] as String? ?? data['groupId'] as String?;
        if (chatId != null) {
          await _markChatAsRead(chatId);
        }
        return;
      }

      _handleGlobalNavigation(data);
    });

    // 2. Foreground will display listener (suppression logic & banner presentation)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) async {
      final data = event.notification.additionalData ?? {};
      final type = data['type'] as String?;
      final incomingChatId =
          data['chatId'] as String? ?? data['groupId'] as String?;

      if (type == 'call') {
        event.preventDefault(); // Suppress standard push card for incoming call UI
        final callId = data['callId'] as String? ?? '';
        final channelName = data['channelName'] as String? ?? '';
        final callerName = data['callerName'] as String? ?? 'Unknown';
        final callerUserId = data['callerUserId'] as String? ?? '';
        final callType = data['callType'] as String? ?? 'audio';
        
        if (callId.isNotEmpty && channelName.isNotEmpty) {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: callId,
              channelName: channelName,
              callerName: callerName,
              callerUserId: callerUserId,
              isVideo: callType == 'video',
            ),
          ));
        }
        return;
      }

      bool isMuted = false;
      if (incomingChatId != null && await _isChatMuted(incomingChatId)) {
        isMuted = true;
      }

      if ((type == 'chat' || type == 'group') &&
          currentActiveChatId != null &&
          incomingChatId == currentActiveChatId) {
        event.preventDefault();
        debugPrint(
            '🔕 Suppressed foreground notification for active chat: $incomingChatId');
        return;
      }

      if (isMuted) {
        event.preventDefault();
        debugPrint(
            '🔕 Suppressed foreground notification for muted chat: $incomingChatId');
      } else {
        // DO NOT call event.preventDefault()!
        // Allow OneSignal to display the foreground notification banner
        final uid = FirebaseService.auth.currentUser?.uid;
        if (uid != null) {
          _playInAppNotificationSound(uid, type, incomingChatId);
        }
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

  // ─── OneSignal Player ID & External User ID Sync ────────

  /// Save OneSignal player ID & bind external user ID to Firestore.
  /// Call this after user signs in.
  static Future<void> syncPlayerId(String uid) async {
    try {
      debugPrint('🔔 Starting OneSignal identity sync for uid: $uid');

      // 1. Log in user to OneSignal SDK to bind external_id = uid
      await OneSignal.User.login(uid);
      await OneSignal.User.addTag('user_id', uid);

      // 2. Request notification permission if not granted
      final isOptedIn = OneSignal.User.pushSubscription.optedIn ?? false;
      debugPrint('🔔 OneSignal optedIn: $isOptedIn');

      if (!isOptedIn) {
        await OneSignal.Notifications.requestPermission(true);
        await Future.delayed(const Duration(seconds: 2));
      }

      // 3. Retry fetching pushSubscription ID
      String? playerId = OneSignal.User.pushSubscription.id;
      int attempts = 0;
      while ((playerId == null || playerId.isEmpty) && attempts < 10) {
        await Future.delayed(const Duration(seconds: 2));
        playerId = OneSignal.User.pushSubscription.id;
        attempts++;
        debugPrint('🔔 Attempt $attempts: $playerId');
      }

      final Map<String, dynamic> updateData = {
        'oneSignalExternalId': uid,
      };
      if (playerId != null && playerId.isNotEmpty) {
        updateData['oneSignalPlayerId'] = playerId;
      }

      await FirebaseService.firestore.collection('users').doc(uid).set(
        updateData,
        SetOptions(merge: true),
      );
      debugPrint('✅ OneSignal sync complete for $uid. Player ID: $playerId');

      _setupSubscriptionObserver(uid);
    } catch (e) {
      debugPrint('⚠️ syncPlayerId error: $e');
    }
  }

  static void _setupSubscriptionObserver(String uid) {
    OneSignal.User.pushSubscription.addObserver((state) async {
      final newId = state.current.id;
      final optedIn = state.current.optedIn;
      debugPrint('📱 OneSignal subscription changed: id=$newId, optedIn=$optedIn');

      if (newId != null && newId.isNotEmpty) {
        await FirebaseService.firestore.collection('users').doc(uid).set({
          'oneSignalPlayerId': newId,
          'oneSignalExternalId': uid,
        }, SetOptions(merge: true));
        debugPrint('✅ Saved OneSignal player ID from observer: $newId');
      }
    });
  }

  // ─── Notification Tap Handlers ──────────────────────────

  static void _handleNotificationNavigation(
      GoRouter router, Map<String, dynamic> data) {
    final type = data['type'];
    switch (type) {
      case 'chat':
        final chatId = data['chatId'] as String?;
        var partnerUid = data['partnerUid'] as String? ?? '';
        final partnerName = data['partnerName'] as String? ?? 'Chat';

        if (partnerUid.isEmpty && chatId != null && chatId.contains('_')) {
          final currentUid = FirebaseService.auth.currentUser?.uid ?? '';
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
        router.go('/home');
        break;
    }
  }

  // ─── Send Notifications via OneSignal REST API ──────────

  /// Send a 1-to-1 chat message notification
  static Future<void> sendMessageNotification({
    String recipientPlayerId = '',
    String recipientUid = '',
    required String senderName,
    required String messageText,
    required String chatId,
    String senderUid = '',
    String senderPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
    String? soundFile,
    int? badgeCount,
  }) async {
    await _sendOneSignalNotification(
      playerIds: recipientPlayerId.isNotEmpty ? [recipientPlayerId] : null,
      recipientUids: recipientUid.isNotEmpty ? [recipientUid] : null,
      title: senderName,
      body: messageText,
      largeIcon: senderPhotoUrl,
      androidChannelId: 'ripple_messages',
      sound: sound,
      vibration: vibration,
      soundFile: soundFile,
      badgeCount: badgeCount,
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
    List<String>? recipientPlayerIds,
    List<String>? recipientUids,
    required String senderName,
    required String groupName,
    required String messageText,
    required String groupId,
    String groupPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
    String? soundFile,
    int? badgeCount,
  }) async {
    await _sendOneSignalNotification(
      playerIds: recipientPlayerIds,
      recipientUids: recipientUids,
      title: groupName,
      body: '$senderName: $messageText',
      largeIcon: groupPhotoUrl,
      androidChannelId: 'ripple_groups',
      sound: sound,
      vibration: vibration,
      soundFile: soundFile,
      badgeCount: badgeCount,
      data: {'type': 'group', 'groupId': groupId},
    );
  }

  /// Send a friend request notification
  static Future<void> sendFriendRequestNotification({
    String recipientPlayerId = '',
    String recipientUid = '',
    required String senderName,
    String senderPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    await _sendOneSignalNotification(
      playerIds: recipientPlayerId.isNotEmpty ? [recipientPlayerId] : null,
      recipientUids: recipientUid.isNotEmpty ? [recipientUid] : null,
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
    String recipientPlayerId = '',
    String recipientUid = '',
    required String reactorName,
    required String emoji,
    String reactorPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
    String? soundFile,
  }) async {
    await _sendOneSignalNotification(
      playerIds: recipientPlayerId.isNotEmpty ? [recipientPlayerId] : null,
      recipientUids: recipientUid.isNotEmpty ? [recipientUid] : null,
      title: 'Status Reaction',
      body: '$reactorName reacted $emoji to your status',
      largeIcon: reactorPhotoUrl,
      androidChannelId: 'ripple_social',
      sound: sound,
      vibration: vibration,
      soundFile: soundFile,
      data: {'type': 'status_reaction'},
    );
  }

  /// Send a call notification with high-priority Android channel
  static Future<void> sendCallNotification({
    String recipientPlayerId = '',
    String recipientUid = '',
    required String callerName,
    required String callerUserId,
    required String callId,
    required String channelName,
    required String callType,
    required bool isGroup,
    String callerPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
    String? soundFile,
  }) async {
    final title = callType == 'video'
        ? '📹 Incoming Video Call'
        : '📞 Incoming Voice Call';
    await _sendOneSignalNotification(
      playerIds: recipientPlayerId.isNotEmpty ? [recipientPlayerId] : null,
      recipientUids: recipientUid.isNotEmpty ? [recipientUid] : null,
      title: title,
      body: '$callerName is calling you',
      largeIcon: callerPhotoUrl,
      androidChannelId: 'ripple_calls',
      sound: sound,
      vibration: vibration,
      soundFile: soundFile,
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
    String recipientPlayerId = '',
    String recipientUid = '',
    required String callerName,
    required String callType,
    String callerPhotoUrl = '',
    bool sound = true,
    bool vibration = true,
  }) async {
    final title = 'Missed Call 📞';
    final body = 'You missed a $callType call from $callerName';
    await _sendOneSignalNotification(
      playerIds: recipientPlayerId.isNotEmpty ? [recipientPlayerId] : null,
      recipientUids: recipientUid.isNotEmpty ? [recipientUid] : null,
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

  // ─── Internal OneSignal REST API Core ───────────────────

  static Future<void> _sendOneSignalNotification({
    List<String>? playerIds,
    List<String>? recipientUids,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int? ttl,
    String? androidChannelId,
    String? largeIcon,
    bool sound = true,
    bool vibration = true,
    String? soundFile,
    int? badgeCount,
  }) async {
    final appId = Env.oneSignalAppId;
    final restKey = Env.oneSignalRestApiKey;

    if (appId.isEmpty || restKey.isEmpty || restKey.contains('your_')) {
      debugPrint('❌ Configure ONESIGNAL_REST_API_KEY in .env file!');
      return;
    }

    final validPids = (playerIds ?? []).where((id) => id.isNotEmpty).toList();
    final validUids = (recipientUids ?? []).where((id) => id.isNotEmpty).toList();

    if (validPids.isEmpty && validUids.isEmpty) {
      debugPrint('⚠️ ONESIGNAL: No recipient player IDs or UIDs provided');
      return;
    }

    try {
      debugPrint('📤 Sending OneSignal notification to ${validPids.length} player(s) & ${validUids.length} uid(s): $title');

      final Map<String, dynamic> payload = {
        'app_id': appId,
        'headings': {'en': title},
        'contents': {'en': body},
        'small_icon': 'ic_stat_notification',
        'priority': 10,
      };

      // Dual targeting: subscription IDs & external_id aliases
      if (validPids.isNotEmpty) {
        payload['include_player_ids'] = validPids;
        payload['include_subscription_ids'] = validPids;
      }
      if (validUids.isNotEmpty) {
        payload['include_aliases'] = {
          'external_id': validUids,
        };
        payload['target_channel'] = 'push';
      }

      // Notification Badge Count management
      if (badgeCount != null) {
        payload['ios_badgeType'] = 'SetTo';
        payload['ios_badgeCount'] = badgeCount;
        payload['android_badge_type'] = 'SetTo';
        payload['android_badge_count'] = badgeCount;
      } else {
        payload['ios_badgeType'] = 'Increase';
        payload['ios_badgeCount'] = 1;
        payload['badge_inc'] = 1;
      }

      // Add WhatsApp styling, threading, and direct reply quick actions
      if (data != null && (data['type'] == 'chat' || data['type'] == 'group')) {
        payload['buttons'] = [
          {'id': 'reply', 'text': 'Reply'},
          {'id': 'read', 'text': 'Mark as Read'},
        ];
        final threadId = data['chatId'] ?? data['groupId'] ?? 'default_thread';
        payload['thread_id'] = threadId;
        payload['android_group'] = threadId;
      }

      if (largeIcon != null && largeIcon.isNotEmpty) payload['large_icon'] = largeIcon;
      if (data != null) payload['data'] = data;
      if (ttl != null) payload['ttl'] = ttl;
      if (androidChannelId != null) payload['android_channel_id'] = androidChannelId;
      if (!sound) {
        payload['ios_sound'] = 'nil';
        payload['android_sound'] = 'nil';
      } else if (soundFile != null && soundFile.isNotEmpty) {
        payload['ios_sound'] = soundFile;
        payload['android_sound'] = soundFile;
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
      debugPrint('✅ OneSignal response: ${response.statusCode} ${response.data}');
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

  static Future<void> _playInAppNotificationSound(
      String uid, String? type, String? incomingChatId) async {
    try {
      String soundName = 'Aqua Chime';
      if (incomingChatId != null) {
        final customNotifDoc = await FirebaseService.firestore
            .collection('users')
            .doc(uid)
            .collection('custom_notifications')
            .doc(incomingChatId)
            .get();
        if (customNotifDoc.exists && (customNotifDoc.data()?['enabled'] ?? false)) {
          soundName = customNotifDoc.data()?['soundName'] as String? ?? 'Aqua Chime';
        } else {
          final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
          final globalSounds = Map<String, dynamic>.from(doc.data()?['notificationSounds'] as Map? ?? {});
          final categoryKey = type == 'group' ? 'groups' : 'messages';
          final info = Map<String, dynamic>.from(globalSounds[categoryKey] as Map? ?? {});
          soundName = info['name']?.toString() ?? 'Aqua Chime';
        }
      }

      final sound = CustomSoundService.getSoundByName(soundName);
      if (sound != null && sound.assetPath.isNotEmpty) {
        await _inAppPlayer.stop();
        await _inAppPlayer.setAsset(sound.assetPath);
        await _inAppPlayer.play();
      }
    } catch (e) {
      debugPrint('⚠️ Error playing in-app sound: $e');
    }
  }

  static Future<void> _markChatAsRead(String chatId) async {
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      await FirebaseService.firestore.collection('chats').doc(chatId).set({
        'unreadCount.$uid': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ Error marking chat read from notification action: $e');
    }
  }
}
