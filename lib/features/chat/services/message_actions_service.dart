import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message_model.dart';
import '../../../core/services/privacy_service.dart';

/// Service for all Phase 1 message actions
/// (reactions, edit, delete, forward, pin, star, seen receipts)
class MessageActionsService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── REACTIONS ──────────────────────────────────────────
  static Future<void> toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
    required bool isGroup,
  }) async {
    final uid = _auth.currentUser!.uid;
    final collection = isGroup ? 'groups' : 'chats';
    final msgRef = _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    final data = doc.data() ?? {};
    final reactions =
        Map<String, dynamic>.from(data['reactions'] as Map? ?? {});

    final currentUids =
        List<String>.from(reactions[emoji] as List? ?? []);

    if (currentUids.contains(uid)) {
      // Remove reaction
      currentUids.remove(uid);
    } else {
      // Add reaction — remove from other emojis first
      for (final key in reactions.keys.toList()) {
        if (key != emoji) {
          final list = List<String>.from(reactions[key] as List? ?? []);
          list.remove(uid);
          if (list.isEmpty) {
            reactions.remove(key);
          } else {
            reactions[key] = list;
          }
        }
      }
      currentUids.add(uid);
    }

    if (currentUids.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = currentUids;
    }

    await msgRef.update({'reactions': reactions});
  }

  // ── EDIT MESSAGE ───────────────────────────────────────
  static Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
    required bool isGroup,
  }) async {
    final uid = _auth.currentUser!.uid;
    final collection = isGroup ? 'groups' : 'chats';
    final msgRef = _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    if (doc.data()?['senderId'] != uid) {
      throw Exception('Can only edit your own messages');
    }

    // Check 15 minute window
    final createdAt = doc.data()?['createdAt'] as Timestamp?;
    final timestamp = doc.data()?['timestamp'] as Timestamp?;
    final ts = createdAt ?? timestamp;
    if (ts != null) {
      final elapsed = DateTime.now().difference(ts.toDate());
      if (elapsed.inMinutes > 15) {
        throw Exception(
            'Messages can only be edited within 15 minutes');
      }
    }

    await msgRef.update({
      'text': newText,
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── DELETE FOR EVERYONE ────────────────────────────────
  static Future<void> deleteForEveryone({
    required String chatId,
    required String messageId,
    required bool isGroup,
  }) async {
    final uid = _auth.currentUser!.uid;
    final collection = isGroup ? 'groups' : 'chats';
    final msgRef = _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    if (doc.data()?['senderId'] != uid) {
      throw Exception(
          'Can only delete your own messages for everyone');
    }

    await msgRef.update({
      'isDeleted': true,
      'text': null,
      'mediaUrl': null,
    });
  }

  // ── DELETE FOR ME ──────────────────────────────────────
  static Future<void> deleteForMe({
    required String chatId,
    required String messageId,
    required bool isGroup,
  }) async {
    final uid = _auth.currentUser!.uid;
    final collection = isGroup ? 'groups' : 'chats';
    await _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'deletedFor': FieldValue.arrayUnion([uid]),
    });
  }

  // ── FORWARD MESSAGE ────────────────────────────────────
  static Future<void> forwardMessage({
    required MessageModel message,
    required List<String> targetChatIds,
    required List<String> targetGroupIds,
  }) async {
    final uid = _auth.currentUser!.uid;
    final batch = _fs.batch();

    for (final chatId in targetChatIds) {
      final msgRef = _fs
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();
      batch.set(msgRef, {
        'senderId': uid,
        'text': message.text,
        'type': message.type,
        'mediaUrl': message.mediaUrl,
        'isForwarded': true,
        'reactions': {},
        'isDeleted': false,
        'isEdited': false,
        'isPinned': false,
        'starredBy': [],
        'deletedFor': [],
        'seenBy': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Update chat lastMessage
      batch.set(
        _fs.collection('chats').doc(chatId),
        {
          'lastMessage': {
            'text': message.text ?? '[forwarded]',
            'senderId': uid,
            'timestamp': FieldValue.serverTimestamp(),
            'type': message.type,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    for (final groupId in targetGroupIds) {
      final msgRef = _fs
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();
      batch.set(msgRef, {
        'senderId': uid,
        'text': message.text,
        'type': message.type,
        'mediaUrl': message.mediaUrl,
        'isForwarded': true,
        'reactions': {},
        'isDeleted': false,
        'isEdited': false,
        'isPinned': false,
        'starredBy': [],
        'deletedFor': [],
        'seenBy': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Update group lastMessage
      batch.update(_fs.collection('groups').doc(groupId), {
        'lastMessage': {
          'text': message.text ?? '[forwarded]',
          'senderId': uid,
          'timestamp': FieldValue.serverTimestamp(),
          'type': message.type,
        },
      });
    }

    await batch.commit();
  }

  // ── PIN MESSAGE ────────────────────────────────────────
  static Future<void> togglePinMessage({
    required String chatId,
    required String messageId,
    required bool pin,
    required bool isGroup,
  }) async {
    final collection = isGroup ? 'groups' : 'chats';

    // Unpin any existing pinned message first
    if (pin) {
      final existing = await _fs
          .collection(collection)
          .doc(chatId)
          .collection('messages')
          .where('isPinned', isEqualTo: true)
          .get();
      for (final doc in existing.docs) {
        await doc.reference.update({'isPinned': false});
      }
    }

    await _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isPinned': pin});

    // Store pinned message id on chat/group doc
    await _fs.collection(collection).doc(chatId).set(
      {'pinnedMessageId': pin ? messageId : null},
      SetOptions(merge: true),
    );
  }

  // ── STAR/SAVE MESSAGE ──────────────────────────────────
  static Future<void> toggleStarMessage({
    required String chatId,
    required String messageId,
    required bool isGroup,
  }) async {
    final uid = _auth.currentUser!.uid;
    final collection = isGroup ? 'groups' : 'chats';
    final msgRef = _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await msgRef.get();
    final starredBy =
        List<String>.from(doc.data()?['starredBy'] as List? ?? []);
    final isStarred = starredBy.contains(uid);

    await msgRef.update({
      'starredBy': isStarred
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
    });

    // Also save to user's saved messages collection
    final savedRef = _fs
        .collection('users')
        .doc(uid)
        .collection('savedMessages')
        .doc(messageId);

    if (isStarred) {
      await savedRef.delete();
    } else {
      await savedRef.set({
        'chatId': chatId,
        'isGroup': isGroup,
        'messageId': messageId,
        'savedAt': FieldValue.serverTimestamp(),
        'text': doc.data()?['text'],
        'type': doc.data()?['type'],
        'mediaUrl': doc.data()?['mediaUrl'],
        'senderId': doc.data()?['senderId'],
      });
    }
  }

  // ── MARK AS SEEN ───────────────────────────────────────
  static Future<void> markMessagesAsSeen({
    required String chatId,
    required String currentUid,
    required bool isGroup,
    int selfDestructSeconds = 0,
  }) async {
    final collection = isGroup ? 'groups' : 'chats';

    // Get last 20 messages (most recent that might be unread)
    final unread = await _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final batch = _fs.batch();
    bool hasUpdates = false;
    final List<DocumentSnapshot> newlySeen = [];
    
    for (final doc in unread.docs) {
      final seenBy =
          List<String>.from(doc.data()['seenBy'] as List? ?? []);
      if (!seenBy.contains(currentUid)) {
        batch.update(doc.reference, {
          'seenBy': FieldValue.arrayUnion([currentUid]),
        });
        hasUpdates = true;
        newlySeen.add(doc);
      }
    }
    if (hasUpdates) {
      await batch.commit();
      
      // Schedule self destruct immediately after commit
      if (selfDestructSeconds > 0) {
        for (final doc in newlySeen) {
          final docData = doc.data() as Map<String, dynamic>?;
          final senderId = docData?['senderId'] as String?;
          if (senderId != currentUid) {
            await PrivacyService.scheduleMessageDelete(
              chatId: chatId,
              messageId: doc.id,
              isGroup: isGroup,
              seconds: selfDestructSeconds,
            );
          }
        }
      }
    }
  }
}
