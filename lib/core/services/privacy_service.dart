import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy & Security service — visibility controls, stealth mode,
/// chat lock, self-destruct timer, and fake passcode.
class PrivacyService {
  static final _fs = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  // ── UPDATE PRIVACY SETTINGS ────────────────────────────
  static Future<void> updatePrivacySettings({
    String? lastSeenVisibility,
    String? profilePhotoVisibility,
    String? bioVisibility,
    String? onlineStatusVisibility,
    bool? stealthMode,
    bool? readReceipts,
    bool? typingIndicator,
  }) async {
    final updates = <String, dynamic>{};

    if (lastSeenVisibility != null) {
      updates['privacy.lastSeenVisibility'] = lastSeenVisibility;
    }
    if (profilePhotoVisibility != null) {
      updates['privacy.profilePhotoVisibility'] = profilePhotoVisibility;
    }
    if (bioVisibility != null) {
      updates['privacy.bioVisibility'] = bioVisibility;
    }
    if (onlineStatusVisibility != null) {
      updates['privacy.onlineStatusVisibility'] = onlineStatusVisibility;
    }
    if (stealthMode != null) {
      updates['privacy.stealthMode'] = stealthMode;
      if (stealthMode) {
        updates['isOnline'] = false;
        updates['lastSeen'] = FieldValue.serverTimestamp();
      }
    }
    if (readReceipts != null) {
      updates['privacy.readReceipts'] = readReceipts;
    }
    if (typingIndicator != null) {
      updates['privacy.typingIndicator'] = typingIndicator;
    }

    if (updates.isNotEmpty) {
      await _fs.collection('users').doc(_uid).update(updates);
    }
  }

  // ── GET PRIVACY SETTINGS ───────────────────────────────
  static Future<Map<String, dynamic>> getPrivacySettings() async {
    try {
      final doc = await _fs.collection('users').doc(_uid).get();
      return Map<String, dynamic>.from(
        doc.data()?['privacy'] as Map? ?? {},
      );
    } catch (e) {
      debugPrint('❌ getPrivacySettings error: $e');
      return {};
    }
  }

  // ── CHECK IF CAN SEE LAST SEEN ─────────────────────────
  static bool canSeeLastSeen({
    required Map<String, dynamic> targetUser,
    required String viewerUid,
    required List<String> viewerFriends,
  }) {
    final privacy =
        Map<String, dynamic>.from(targetUser['privacy'] as Map? ?? {});
    final visibility =
        privacy['lastSeenVisibility'] as String? ?? 'everyone';
    final targetUid = targetUser['uid'] as String? ?? '';

    if (targetUid == viewerUid) return true;

    switch (visibility) {
      case 'everyone':
        return true;
      case 'friends':
        return viewerFriends.contains(targetUid);
      case 'nobody':
        return false;
      default:
        return true;
    }
  }

  // ── CHECK IF CAN SEE ONLINE STATUS ─────────────────────
  static bool canSeeOnlineStatus({
    required Map<String, dynamic> targetUser,
    required String viewerUid,
    required List<String> viewerFriends,
  }) {
    final privacy =
        Map<String, dynamic>.from(targetUser['privacy'] as Map? ?? {});

    final stealth = privacy['stealthMode'] as bool? ?? false;
    if (stealth) return false;

    final visibility =
        privacy['onlineStatusVisibility'] as String? ?? 'everyone';
    final targetUid = targetUser['uid'] as String? ?? '';

    if (targetUid == viewerUid) return true;

    switch (visibility) {
      case 'everyone':
        return true;
      case 'friends':
        return viewerFriends.contains(targetUid);
      case 'nobody':
        return false;
      default:
        return true;
    }
  }

  // ── SELF DESTRUCT — SET PER CHAT ───────────────────────
  static Future<void> setSelfDestructTimer({
    required String chatId,
    required bool isGroup,
    required int seconds,
  }) async {
    final collection = isGroup ? 'groups' : 'chats';
    await _fs.collection(collection).doc(chatId).update({
      'selfDestructTimer': seconds,
      'selfDestructSetBy': _uid,
    });
  }

  // ── SELF DESTRUCT — SCHEDULE DELETE ────────────────────
  static Future<void> scheduleMessageDelete({
    required String chatId,
    required String messageId,
    required bool isGroup,
    required int seconds,
  }) async {
    if (seconds <= 0) return;

    final collection = isGroup ? 'groups' : 'chats';
    final deleteAt = Timestamp.fromDate(
      DateTime.now().add(Duration(seconds: seconds)),
    );

    await _fs
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'deleteAt': deleteAt});
  }

  // ── CHAT LOCK ──────────────────────────────────────────
  static Future<void> lockChat(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getStringList('locked_chats') ?? [];
    if (!locked.contains(chatId)) {
      locked.add(chatId);
      await prefs.setStringList('locked_chats', locked);
    }
  }

  static Future<void> unlockChatLock(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getStringList('locked_chats') ?? [];
    locked.remove(chatId);
    await prefs.setStringList('locked_chats', locked);
  }

  static Future<bool> isChatLocked(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getStringList('locked_chats') ?? [];
    return locked.contains(chatId);
  }

  static Future<List<String>> getLockedChats() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('locked_chats') ?? [];
  }

  // ── FAKE PASSCODE ──────────────────────────────────────
  static Future<void> setFakePasscode(String passcode) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = _hashPasscode(passcode);
    await prefs.setString('fake_passcode', hashed);
    await prefs.setBool('fake_passcode_enabled', true);
  }

  static Future<bool> checkFakePasscode(String passcode) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('fake_passcode');
    if (stored == null) return false;
    return stored == _hashPasscode(passcode);
  }

  static Future<bool> isFakePasscodeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('fake_passcode_enabled') ?? false;
  }

  static String _hashPasscode(String passcode) {
    final bytes = utf8.encode('ripple_$passcode');
    return sha256.convert(bytes).toString();
  }
}
