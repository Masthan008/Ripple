import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service for scheduling messages to be sent at a future time.
class ScheduleService {
  ScheduleService._();

  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── SCHEDULE MESSAGE ───────────────────────────────────

  static Future<void> scheduleMessage({
    required String chatId,
    required bool isGroup,
    required String text,
    required DateTime sendAt,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _fs.collection('scheduledMessages').add({
      'senderId': uid,
      'chatId': chatId,
      'isGroup': isGroup,
      'text': text,
      'type': 'text',
      'sendAt': Timestamp.fromDate(sendAt),
      'sent': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── DELETE SCHEDULED ───────────────────────────────────

  static Future<void> deleteScheduled(String msgId) async {
    await _fs.collection('scheduledMessages').doc(msgId).delete();
  }

  // ── GET MY SCHEDULED FOR A CHAT ────────────────────────

  static Stream<List<Map<String, dynamic>>> getMyScheduled(String chatId) {
    final uid = _auth.currentUser!.uid;
    return _fs
        .collection('scheduledMessages')
        .where('senderId', isEqualTo: uid)
        .where('chatId', isEqualTo: chatId)
        .where('sent', isEqualTo: false)
        .orderBy('sendAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  // ── START PERIODIC CHECKER ─────────────────────────────
  // Checks every 30 seconds for due messages and sends them.

  static Timer? _timer;

  static void startScheduleChecker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _sendDueMessages();
    });
  }

  static void stopScheduleChecker() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _sendDueMessages() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final due = await _fs
          .collection('scheduledMessages')
          .where('senderId', isEqualTo: uid)
          .where('sent', isEqualTo: false)
          .where('sendAt', isLessThanOrEqualTo: Timestamp.now())
          .limit(10)
          .get();

      for (final doc in due.docs) {
        final data = doc.data();
        try {
          final collection =
              (data['isGroup'] as bool? ?? false) ? 'groups' : 'chats';

          await _fs
              .collection(collection)
              .doc(data['chatId'] as String)
              .collection('messages')
              .add({
            'senderId': uid,
            'text': data['text'],
            'type': 'text',
            'createdAt': FieldValue.serverTimestamp(),
            'isDeleted': false,
            'reactions': {},
            'isScheduled': true,
          });

          // Mark as sent
          await doc.reference.update({'sent': true});

          // Update chat's lastMessage
          await _fs
              .collection(collection)
              .doc(data['chatId'] as String)
              .update({
            'lastMessage': data['text'],
            'lastMessageAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Failed to send scheduled message: $e');
        }
      }
    } catch (e) {
      debugPrint('Schedule checker error: $e');
    }
  }
}
