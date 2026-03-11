import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/status_model.dart';

/// Service for creating, reading, and managing statuses in Firestore.
class StatusService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── POST STATUS ───────────────────────────────────────
  static Future<void> postStatus({
    required String type,
    String? mediaUrl,
    String? text,
    List<String>? gradientColors,
    String? mood,
    String privacy = 'friends',
  }) async {
    final user = _auth.currentUser!;
    final userDoc =
        await _fs.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final now = DateTime.now();
    final expiresAt = Timestamp.fromDate(
      now.add(const Duration(hours: 24)),
    );
    final createdAt = Timestamp.fromDate(now);

    await _fs.collection('statuses').add({
      'uid': user.uid,
      'ownerName': userData['name'] ?? user.displayName ?? '',
      'ownerPhoto': userData['photoUrl'] ?? user.photoURL ?? '',
      'type': type,
      'mediaUrl': mediaUrl,
      'text': text,
      'gradientColors': gradientColors,
      'mood': mood,
      'viewers': [],
      'reactions': {},
      'privacy': privacy,
      'customViewers': [],
      'expiresAt': expiresAt,
      'createdAt': createdAt,
    });

    // If mood status, also update user document
    if (type == 'mood' && mood != null) {
      await _fs.collection('users').doc(user.uid).set({
        'currentMood': mood,
        'moodExpiresAt': expiresAt,
      }, SetOptions(merge: true));
    }
  }

  // ── DELETE STATUS ─────────────────────────────────────
  static Future<void> deleteStatus(String statusId) async {
    await _fs.collection('statuses').doc(statusId).delete();
  }

  // ── MARK AS VIEWED ────────────────────────────────────
  static Future<void> markViewed({
    required String statusId,
    required String viewerName,
  }) async {
    final uid = _auth.currentUser!.uid;
    final statusRef = _fs.collection('statuses').doc(statusId);

    final doc = await statusRef.get();
    if (!doc.exists) return;

    final viewers = List<Map<String, dynamic>>.from(
      doc.data()?['viewers'] as List? ?? [],
    );

    final alreadyViewed = viewers.any((v) => v['uid'] == uid);
    if (alreadyViewed) return;

    await statusRef.update({
      'viewers': FieldValue.arrayUnion([
        {
          'uid': uid,
          'name': viewerName,
          'viewedAt': Timestamp.now(),
        }
      ]),
    });
  }

  // ── REACT TO STATUS ───────────────────────────────────
  static Future<void> reactToStatus({
    required String statusId,
    required String emoji,
  }) async {
    final uid = _auth.currentUser!.uid;
    await _fs.collection('statuses').doc(statusId).update({
      'reactions.$uid': emoji,
    });
  }

  // ── GET FRIENDS STATUSES ──────────────────────────────
  static Stream<List<StatusModel>> getFriendsStatuses(
      List<String> friendUids) {
    if (friendUids.isEmpty) return Stream.value([]);

    // Firestore whereIn limit is 30
    final uids = friendUids.take(30).toList();

    return _fs
        .collection('statuses')
        .where('uid', whereIn: uids)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(StatusModel.fromFirestore)
            .where((s) => !s.isExpired)
            .toList());
  }

  // ── GET MY STATUSES ───────────────────────────────────
  static Stream<List<StatusModel>> getMyStatuses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _fs
        .collection('statuses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(StatusModel.fromFirestore)
            .where((s) => !s.isExpired)
            .toList());
  }

  // ── CLEANUP EXPIRED (call on app open) ────────────────
  static Future<void> cleanupExpired() async {
    try {
      final expired = await _fs
          .collection('statuses')
          .where('expiresAt', isLessThan: Timestamp.now())
          .limit(50)
          .get();

      if (expired.docs.isEmpty) return;

      final batch = _fs.batch();
      for (final doc in expired.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Status cleanup error: $e');
    }
  }

  // ── CLEAR EXPIRED MOOD ────────────────────────────────
  static Future<void> clearExpiredMood() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final userDoc =
          await _fs.collection('users').doc(uid).get();
      final moodExpiry =
          userDoc.data()?['moodExpiresAt'] as Timestamp?;

      if (moodExpiry != null &&
          DateTime.now().isAfter(moodExpiry.toDate())) {
        await _fs.collection('users').doc(uid).update({
          'currentMood': FieldValue.delete(),
          'moodExpiresAt': FieldValue.delete(),
        });
      }
    } catch (e) {
      debugPrint('Mood cleanup error: $e');
    }
  }
}
