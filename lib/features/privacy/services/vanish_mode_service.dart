import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firebase_service.dart';

/// Service to manage disappearing messages (Vanish Mode).
/// 
/// When enabled, new messages sent in a chat will have an 'expiresAt' field.
/// The service handles toggling the mode and reading its state from the chat document.
class VanishModeService {
  static final _firestore = FirebaseService.firestore;

  /// Toggles vanish mode for a specific chat.
  static Future<void> toggleVanishMode({
    required String chatId,
    required bool isGroup,
    required bool enabled,
    int durationSeconds = 86400, // Default 24 hours
  }) async {
    final collection = isGroup ? 'groups' : 'chats';
    
    await _firestore.collection(collection).doc(chatId).set(
      {
        'vanishMode': enabled
            ? {
                'enabled': true,
                'durationSeconds': durationSeconds,
              }
            : null,
      },
      SetOptions(merge: true),
    );
  }

  /// Calculates the expiration timestamp for a new message if Vanish Mode is active.
  /// Returns null if Vanish Mode is currently off.
  static Timestamp? calculateExpiration(Map<String, dynamic>? vanishModeData) {
    if (vanishModeData == null || vanishModeData['enabled'] != true) {
      return null;
    }

    final durationSeconds = vanishModeData['durationSeconds'] as int? ?? 86400;
    return Timestamp.fromDate(
      DateTime.now().add(Duration(seconds: durationSeconds)),
    );
  }

  /// Filters out messages that have expired and should no longer be displayed.
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> filterActiveMessages(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> messages) {
    final now = DateTime.now();
    return messages.where((doc) {
      final docData = doc.data();
      final expiresAt = docData['expiresAt'] as Timestamp?;
      
      if (expiresAt == null) return true; // Never expires
      
      // Keep if expiration time is still in the future
      return expiresAt.toDate().isAfter(now);
    }).toList();
  }
}
