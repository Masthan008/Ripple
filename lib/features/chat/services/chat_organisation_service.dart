import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Unified service for chat pinning, archiving, folders, and saved messages.
class ChatOrganisationService {
  ChatOrganisationService._();

  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static String get _uid => _auth.currentUser!.uid;

  // ─── PIN / UNPIN ────────────────────────────────────────

  /// Pin a chat (max 3). Returns error string or null on success.
  static Future<String?> pinChat(String chatId) async {
    final userDoc = await _fs.collection('users').doc(_uid).get();
    final pinned =
        List<String>.from(userDoc.data()?['pinnedChats'] as List? ?? []);

    if (pinned.contains(chatId)) return 'Already pinned';
    if (pinned.length >= 3) return 'Maximum 3 chats can be pinned';

    await _fs.collection('users').doc(_uid).update({
      'pinnedChats': FieldValue.arrayUnion([chatId]),
    });
    return null;
  }

  static Future<void> unpinChat(String chatId) async {
    await _fs.collection('users').doc(_uid).update({
      'pinnedChats': FieldValue.arrayRemove([chatId]),
    });
  }

  // ─── ARCHIVE / UNARCHIVE ────────────────────────────────

  static Future<void> archiveChat(String chatId) async {
    await _fs.collection('users').doc(_uid).update({
      'archivedChats': FieldValue.arrayUnion([chatId]),
      'pinnedChats': FieldValue.arrayRemove([chatId]),
    });
  }

  static Future<void> unarchiveChat(String chatId) async {
    await _fs.collection('users').doc(_uid).update({
      'archivedChats': FieldValue.arrayRemove([chatId]),
    });
  }

  // ─── FOLDER MANAGEMENT ─────────────────────────────────

  static Future<void> addChatToFolder({
    required String folderId,
    required String chatId,
  }) async {
    await _fs
        .collection('users')
        .doc(_uid)
        .collection('folders')
        .doc(folderId)
        .update({
      'chatIds': FieldValue.arrayUnion([chatId]),
    });
  }

  static Future<void> removeChatFromFolder({
    required String folderId,
    required String chatId,
  }) async {
    await _fs
        .collection('users')
        .doc(_uid)
        .collection('folders')
        .doc(folderId)
        .update({
      'chatIds': FieldValue.arrayRemove([chatId]),
    });
  }

  static Future<void> createFolder({
    required String name,
    required String icon,
    required String color,
    required int order,
  }) async {
    await _fs
        .collection('users')
        .doc(_uid)
        .collection('folders')
        .add({
      'name': name,
      'icon': icon,
      'color': color,
      'chatIds': <String>[],
      'groupIds': <String>[],
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteFolder(String folderId) async {
    await _fs
        .collection('users')
        .doc(_uid)
        .collection('folders')
        .doc(folderId)
        .delete();
  }

  // ─── SAVED MESSAGES ─────────────────────────────────────

  static Future<void> saveMessage({
    required String originalChatId,
    required String originalMessageId,
    required Map<String, dynamic> messageData,
    required String senderName,
    required String senderPhoto,
  }) async {
    await _fs
        .collection('users')
        .doc(_uid)
        .collection('savedMessages')
        .doc(originalMessageId)
        .set({
      'originalChatId': originalChatId,
      'originalMessageId': originalMessageId,
      'senderId': messageData['senderId'],
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'type': messageData['type'] ?? 'text',
      'text': messageData['text'],
      'mediaUrl': messageData['mediaUrl'],
      'savedAt': FieldValue.serverTimestamp(),
      'originalCreatedAt': messageData['createdAt'],
    });
  }

  static Future<void> unsaveMessage(String originalMessageId) async {
    await _fs
        .collection('users')
        .doc(_uid)
        .collection('savedMessages')
        .doc(originalMessageId)
        .delete();
  }

  static Stream<List<Map<String, dynamic>>> getSavedMessages() {
    return _fs
        .collection('users')
        .doc(_uid)
        .collection('savedMessages')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {
                  ...d.data(),
                  'id': d.id,
                })
            .toList());
  }

  // ─── MUTE / UNMUTE ─────────────────────────────────────

  static Future<void> muteChat(String chatId) async {
    await _fs.collection('users').doc(_uid).update({
      'mutedChats': FieldValue.arrayUnion([chatId]),
    });
  }

  static Future<void> unmuteChat(String chatId) async {
    await _fs.collection('users').doc(_uid).update({
      'mutedChats': FieldValue.arrayRemove([chatId]),
    });
  }
}
