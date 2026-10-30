import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/account_vault_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/models/user_model.dart';

final webCompanionServiceProvider = Provider<WebCompanionService>((ref) {
  return WebCompanionService();
});

class WebCompanionService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  static const _uuid = Uuid();

  static const String keyLinkedUid = 'web_companion_uid';
  static const String keySessionId = 'web_companion_session_id';
  static const String keyEmail = 'web_companion_email';
  static const String keyPassword = 'web_companion_password';
  static const String keyDisplayName = 'web_companion_name';
  static const String keyPhotoUrl = 'web_companion_photo';

  /// Generates a new pairing session for the web client
  Future<String> createPairingSession() async {
    final sessionId = _uuid.v4();
    await _firestore.collection('pairing_sessions').doc(sessionId).set({
      'sessionId': sessionId,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 2))),
      'platform': 'Web Browser',
    });
    return sessionId;
  }

  /// Real-time stream of the pairing session document
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamPairingSession(String sessionId) {
    return _firestore.collection('pairing_sessions').doc(sessionId).snapshots();
  }

  /// Called by the primary mobile app when scanning the Web QR code
  Future<void> approvePairingSession({
    required String sessionId,
    required UserModel user,
    String? browserInfo,
  }) async {
    final batch = _firestore.batch();

    // Look up password if available from AccountVault
    String? authPassword;
    try {
      final accounts = await AccountVaultService.getSavedAccounts();
      final current = accounts.firstWhere(
        (a) => a.uid == user.uid,
        orElse: () => SavedAccount(uid: user.uid, email: user.email, displayName: user.name, lastActive: DateTime.now()),
      );
      authPassword = current.password;
    } catch (_) {}

    // 1. Update the pairing handshake session to approved with credentials
    final pairingDoc = _firestore.collection('pairing_sessions').doc(sessionId);
    final sessionPayload = <String, dynamic>{
      'status': 'approved',
      'uid': user.uid,
      'email': user.email,
      'displayName': user.name,
      'photoUrl': user.photoUrl,
      'approvedAt': FieldValue.serverTimestamp(),
    };
    if (authPassword != null && authPassword.isNotEmpty) {
      sessionPayload['authPassword'] = authPassword;
    }
    batch.update(pairingDoc, sessionPayload);

    // 2. Add companion device record under the user's devices subcollection
    final deviceDoc = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(sessionId);

    batch.set(deviceDoc, {
      'id': sessionId,
      'platform': 'Web Browser',
      'deviceName': browserInfo ?? 'Ripple Web Companion',
      'linkedAt': FieldValue.serverTimestamp(),
      'lastActive': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    await batch.commit();
  }

  /// Finalize login on the Web side and persist session tokens
  Future<void> completeWebLogin({
    required String sessionId,
    required String uid,
    String? email,
    String? password,
    String? displayName,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLinkedUid, uid);
    await prefs.setString(keySessionId, sessionId);
    if (email != null && email.isNotEmpty) await prefs.setString(keyEmail, email);
    if (password != null && password.isNotEmpty) await prefs.setString(keyPassword, password);
    if (displayName != null) await prefs.setString(keyDisplayName, displayName);
    if (photoUrl != null) await prefs.setString(keyPhotoUrl, photoUrl);

    // Clean up temporary pairing handshake doc
    try {
      await _firestore.collection('pairing_sessions').doc(sessionId).delete();
    } catch (e) {
      debugPrint('Pairing session cleanup notice: $e');
    }
  }

  /// Check if the Web Client currently has an active saved session
  Future<Map<String, String>?> getSavedWebSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(keyLinkedUid);
    final sessionId = prefs.getString(keySessionId);

    if (uid == null || uid.isEmpty || sessionId == null || sessionId.isEmpty) {
      return null;
    }

    return {
      'uid': uid,
      'sessionId': sessionId,
      'email': prefs.getString(keyEmail) ?? '',
      'password': prefs.getString(keyPassword) ?? '',
      'displayName': prefs.getString(keyDisplayName) ?? 'User',
      'photoUrl': prefs.getString(keyPhotoUrl) ?? '',
    };
  }

  /// Unlink/Log out the web companion
  Future<void> unlinkWebSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(keyLinkedUid);
    final sessionId = prefs.getString(keySessionId);

    // 1. Immediately wipe all local credentials so browser is unlinked locally
    await prefs.remove(keyLinkedUid);
    await prefs.remove(keySessionId);
    await prefs.remove(keyEmail);
    await prefs.remove(keyPassword);
    await prefs.remove(keyDisplayName);
    await prefs.remove(keyPhotoUrl);

    // Also sign out Firebase on Web
    try {
      await FirebaseService.auth.signOut();
    } catch (_) {}

    // 2. Non-blocking fire-and-forget deletion of device document with strict timeout
    if (uid != null && sessionId != null) {
      unawaited(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(sessionId)
            .delete()
            .timeout(const Duration(seconds: 1))
            .catchError((e) {
              debugPrint('Web unlinking remote cleanup note: $e');
            }),
      );
    }
  }

  /// Stream active device status — triggers automatic sign-out if session is revoked from phone
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDeviceStatus(String uid, String sessionId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(sessionId)
        .snapshots();
  }
}
