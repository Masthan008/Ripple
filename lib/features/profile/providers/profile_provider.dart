import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';


// ─── Profile Service Provider ────────────────────────────
final profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());

class ProfileService {
  final _firestore = FirebaseService.firestore;
  final _auth = FirebaseService.auth;

  String get _myUid => _auth.currentUser!.uid;

  /// Update display name
  Future<void> updateName(String name) async {
    await _auth.currentUser!.updateDisplayName(name);
    await _firestore.collection('users').doc(_myUid).update({
      'name': name,
    });
  }

  /// Update profile photo URL
  Future<void> updateProfilePhoto(String photoUrl) async {
    await _auth.currentUser!.updatePhotoURL(photoUrl);
    await _firestore.collection('users').doc(_myUid).update({
      'photoUrl': photoUrl,
    });
  }

  /// Update typing status
  Future<void> setTypingTo(String targetId) async {
    await _firestore.collection('users').doc(_myUid).update({
      'isTypingTo': targetId,
    });
  }

  /// Clear typing status
  Future<void> clearTyping() async {
    await _firestore.collection('users').doc(_myUid).update({
      'isTypingTo': '',
    });
  }

  /// Set online status
  Future<void> setOnlineStatus(bool isOnline) async {
    await _firestore.collection('users').doc(_myUid).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
