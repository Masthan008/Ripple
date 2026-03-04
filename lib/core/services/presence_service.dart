import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'firebase_service.dart';

/// Real-time presence using Firebase Realtime Database.
///
/// Uses RTDB's `onDisconnect()` for instant offline detection
/// (works even if the app is force-killed), and syncs status
/// back to Firestore so existing listeners still work.
class PresenceService {
  PresenceService._();

  static final _rtdb = FirebaseDatabase.instance;

  /// Initialize presence tracking for the given user.
  /// Call once after the user is confirmed logged in.
  static Future<void> initialize(String uid) async {
    if (uid.isEmpty) return;

    final userStatusRTDB = _rtdb.ref('status/$uid');
    final userStatusFirestore =
        FirebaseService.firestore.collection('users').doc(uid);

    final onlineData = {
      'state': 'online',
      'lastSeen': ServerValue.timestamp,
    };

    final offlineData = {
      'state': 'offline',
      'lastSeen': ServerValue.timestamp,
    };

    // Listen to Firebase's own connection state
    _rtdb.ref('.info/connected').onValue.listen((event) async {
      final connected = event.snapshot.value as bool? ?? false;
      if (!connected) return;

      try {
        // 1. Set onDisconnect handler FIRST (critical order — if we lose
        //    connection before step 2, this still fires)
        await userStatusRTDB.onDisconnect().set(offlineData);

        // 2. Set online status in RTDB
        await userStatusRTDB.set(onlineData);

        // 3. Set online in Firestore
        await userStatusFirestore.set({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('⚠️ Presence init error: $e');
      }
    });

    // Listen to RTDB changes and sync to Firestore
    userStatusRTDB.onValue.listen((event) async {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;

      final isOnline = data['state'] == 'online';
      try {
        await userStatusFirestore.set({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    });

    debugPrint('✅ PresenceService initialized for $uid');
  }

  /// Manually set user offline (e.g. app paused)
  static Future<void> setOffline(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _rtdb.ref('status/$uid').set({
        'state': 'offline',
        'lastSeen': ServerValue.timestamp,
      });
      await FirebaseService.firestore.collection('users').doc(uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Manually set user online (e.g. app resumed)
  static Future<void> setOnline(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _rtdb.ref('status/$uid').set({
        'state': 'online',
        'lastSeen': ServerValue.timestamp,
      });
      await FirebaseService.firestore.collection('users').doc(uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
