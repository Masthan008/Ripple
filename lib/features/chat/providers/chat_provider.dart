import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/models/user_model.dart';
import '../models/message_model.dart';

const _uuid = Uuid();

// ─── Chat Messages Stream Provider ───────────────────────
/// Real-time stream of messages for a specific chat
final chatMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.chatsCollection
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc))
          .toList());
});

// ─── Chat Partner Provider ───────────────────────────────
/// Stream of the chat partner's user data (for online status, typing, etc.)
final chatPartnerProvider =
    StreamProvider.family<UserModel?, String>((ref, partnerUid) {
  return FirebaseService.usersCollection
      .doc(partnerUid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  });
});

// ─── Chat Service ────────────────────────────────────────
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

class ChatService {
  final _firestore = FirebaseService.firestore;
  final _auth = FirebaseService.auth;

  String get _myUid => _auth.currentUser?.uid ?? '';

  /// Public getter for current user UID
  String get myUid => _myUid;

  /// Generate chat ID from two user UIDs (sorted & joined)
  String getChatId(String otherUid) => Helpers.getChatId(_myUid, otherUid);

  /// Send a text message (supports replyTo for Phase 1)
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String type = 'text',
    String? mediaUrl,
    String? fileName,
    ReplyData? replyTo,
    bool isForwarded = false,
  }) async {
    if (_myUid.isEmpty) return; // Guard during auth transition

    final otherUid = _getOtherUid(chatId);

    // ── Block check ──────────────────────────────────────
    // Check if either user has blocked the other
    final recipientDoc =
        await _firestore.collection('users').doc(otherUid).get();
    final theirBlockedList = List<String>.from(
        recipientDoc.data()?['blockedUsers'] as List? ?? []);

    if (theirBlockedList.contains(_myUid)) {
      debugPrint('🚫 Message blocked — recipient has blocked sender');
      return;
    }

    final myDoc =
        await _firestore.collection('users').doc(_myUid).get();
    final myBlockedList = List<String>.from(
        myDoc.data()?['blockedUsers'] as List? ?? []);

    if (myBlockedList.contains(otherUid)) {
      throw Exception(
          'You have blocked this user. Unblock them to send messages.');
    }

    // ── Send message ─────────────────────────────────────
    final messageId = _uuid.v4();
    final message = MessageModel(
      id: messageId,
      senderId: _myUid,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      replyTo: replyTo,
      isForwarded: isForwarded,
      seenBy: [_myUid],
      createdAt: DateTime.now(),
    );

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc(messageId);

    final batch = _firestore.batch();

    // Write message document
    batch.set(messageRef, message.toMap());

    // Update chat document with last message info
    batch.set(
      chatRef,
      {
        'lastMessage': {
          'text': type == 'text' ? text : '[$type]',
          'senderId': _myUid,
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'type': type,
        },
        'participants': _getChatParticipants(chatId),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Increment unread count for the other user
    batch.set(
      chatRef,
      {
        'unreadCount.$otherUid': FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    // Send push notification via OneSignal
    try {
      final otherDoc = await _firestore.collection('users').doc(otherUid).get();
      final playerId = otherDoc.data()?['oneSignalPlayerId'] as String?;
      final myName = myDoc.data()?['name'] as String? ?? 'Someone';

      if (playerId != null && playerId.isNotEmpty) {
        final notifText = type == 'text'
            ? text
            : type == 'image'
                ? '📷 Sent a photo'
                : type == 'video'
                    ? '🎥 Sent a video'
                    : '📎 Sent a file';
        await NotificationService.sendMessageNotification(
          recipientPlayerId: playerId,
          senderName: myName,
          messageText: notifText,
          chatId: chatId,
          senderUid: _myUid,
        );
      }
    } catch (_) {}
  }

  /// Mark all messages in a chat as read (for the current user)
  Future<void> markAsRead(String chatId) async {
    // Reset unread count
    await _firestore.collection('chats').doc(chatId).set(
      {'unreadCount.$_myUid': 0},
      SetOptions(merge: true),
    );

    // Mark individual messages as read (legacy support)
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: _myUid)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  /// Create or ensure a chat document exists
  Future<String> ensureChat(String otherUid) async {
    final chatId = getChatId(otherUid);
    final chatRef = _firestore.collection('chats').doc(chatId);
    final doc = await chatRef.get();

    if (!doc.exists) {
      await chatRef.set({
        'participants': [_myUid, otherUid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadCount': {_myUid: 0, otherUid: 0},
        'lastMessage': null,
      });
    }

    return chatId;
  }

  /// Get all chats for the current user
  Stream<List<Map<String, dynamic>>> getMyChats() {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: _myUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['chatId'] = doc.id;
              return data;
            }).toList());
  }

  /// Set typing status
  Future<void> setTypingTo(String targetId) async {
    try {
      await _firestore.collection('users').doc(_myUid).update({
        'isTypingTo': targetId,
      });
    } catch (e) {
      debugPrint('⚠️ setTypingTo failed: $e');
    }
  }

  /// Clear typing status
  Future<void> clearTyping() async {
    try {
      await _firestore.collection('users').doc(_myUid).update({
        'isTypingTo': '',
      });
    } catch (e) {
      debugPrint('⚠️ clearTyping failed: $e');
    }
  }

  /// Extract participants from chatId
  List<String> _getChatParticipants(String chatId) {
    return chatId.split('_');
  }

  /// Get the other user's UID from chatId
  String _getOtherUid(String chatId) {
    final parts = chatId.split('_');
    return parts[0] == _myUid ? parts[1] : parts[0];
  }
}
