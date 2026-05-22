import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_service.dart';

/// Secret Chat Service — End-to-End Encrypted Messaging
///
/// Provides AES-256-CBC encryption for Secret Chat messages.
/// Keys are generated per-chat and stored exclusively in the
/// device's secure storage (Keystore on Android, Keychain on iOS).
///
/// Flow:
/// 1. User creates a Secret Chat → a random 256-bit AES key is
///    generated and stored locally via `FlutterSecureStorage`.
/// 2. On send: plaintext is encrypted with the chat key + random IV.
///    The ciphertext + IV are written to Firestore.
/// 3. On receive: ciphertext + IV are read from Firestore and
///    decrypted locally using the stored key.
///
/// Key sharing between devices is left to a future QR-code or
/// out-of-band exchange mechanism.
class SecretChatService {
  SecretChatService._();
  static final SecretChatService instance = SecretChatService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Key Management ──────────────────────────────────────

  /// Generate and store a new AES-256 key for a secret chat.
  Future<String> generateAndStoreKey(String chatId) async {
    final key = encrypt.Key.fromSecureRandom(32); // 256-bit
    await _storage.write(
      key: 'secret_chat_key_$chatId',
      value: key.base64,
    );
    return key.base64;
  }

  /// Retrieve the stored key for a secret chat.
  Future<encrypt.Key?> getKey(String chatId) async {
    final base64Key = await _storage.read(key: 'secret_chat_key_$chatId');
    if (base64Key == null || base64Key.isEmpty) return null;
    return encrypt.Key.fromBase64(base64Key);
  }

  /// Check if a key exists for a chat.
  Future<bool> hasKey(String chatId) async {
    final key = await _storage.read(key: 'secret_chat_key_$chatId');
    return key != null && key.isNotEmpty;
  }

  /// Delete the key when a secret chat is destroyed.
  Future<void> deleteKey(String chatId) async {
    await _storage.delete(key: 'secret_chat_key_$chatId');
  }

  /// Export the key as a base64 string (for QR-code sharing).
  Future<String?> exportKey(String chatId) async {
    return await _storage.read(key: 'secret_chat_key_$chatId');
  }

  /// Import a key from a base64 string (scanned from QR code).
  Future<void> importKey(String chatId, String base64Key) async {
    await _storage.write(
      key: 'secret_chat_key_$chatId',
      value: base64Key,
    );
  }

  // ─── Encryption / Decryption ─────────────────────────────

  /// Encrypt a plaintext message using the chat's AES key.
  /// Returns a map with `encryptedText` and `iv` (both base64).
  Future<Map<String, String>?> encryptMessage(
    String chatId,
    String plaintext,
  ) async {
    final key = await getKey(chatId);
    if (key == null) {
      debugPrint('❌ SecretChat: No key found for chat $chatId');
      return null;
    }

    final iv = encrypt.IV.fromSecureRandom(16); // 128-bit IV
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return {
      'encryptedText': encrypted.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypt a ciphertext message using the chat's AES key.
  Future<String?> decryptMessage(
    String chatId,
    String encryptedBase64,
    String ivBase64,
  ) async {
    final key = await getKey(chatId);
    if (key == null) {
      debugPrint('❌ SecretChat: No key found for chat $chatId');
      return null;
    }

    try {
      final iv = encrypt.IV.fromBase64(ivBase64);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );

      final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
      return decrypted;
    } catch (e) {
      debugPrint('❌ SecretChat decryption failed: $e');
      return null;
    }
  }

  // ─── Firestore Operations ────────────────────────────────

  /// Create a new secret chat between two users.
  /// Returns the chat document ID.
  Future<String> createSecretChat({
    required String currentUid,
    required String partnerUid,
  }) async {
    // Generate a deterministic chat ID (sorted UIDs)
    final ids = [currentUid, partnerUid]..sort();
    final chatId = 'secret_${ids[0]}_${ids[1]}';

    // Check if it already exists
    final existing = await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .get();

    if (!existing.exists) {
      await FirebaseService.firestore
          .collection('secretChats')
          .doc(chatId)
          .set({
        'participants': [currentUid, partnerUid],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isGroup': false,
        'encrypted': true,
      });

      // Add to both users' secretChats arrays
      for (final uid in [currentUid, partnerUid]) {
        await FirebaseService.firestore
            .collection('users')
            .doc(uid)
            .update({
          'secretChats': FieldValue.arrayUnion([chatId]),
        }).catchError((_) async {
          // Field might not exist yet
          await FirebaseService.firestore
              .collection('users')
              .doc(uid)
              .set({'secretChats': [chatId]}, SetOptions(merge: true));
        });
      }
    }

    // Generate and store key locally (only if we don't have one)
    if (!await hasKey(chatId)) {
      await generateAndStoreKey(chatId);
    }

    return chatId;
  }

  /// Send an encrypted message to a secret chat.
  Future<void> sendEncryptedMessage({
    required String chatId,
    required String senderId,
    required String plaintext,
  }) async {
    final encrypted = await encryptMessage(chatId, plaintext);
    if (encrypted == null) {
      throw Exception('Failed to encrypt message — no key available');
    }

    await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .collection('messages')
        .add({
      'encryptedText': encrypted['encryptedText'],
      'iv': encrypted['iv'],
      'senderId': senderId,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    });

    // Update the chat's timestamp
    await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .update({
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  /// Get a stream of decrypted messages for a secret chat.
  Stream<List<Map<String, dynamic>>> getDecryptedMessagesStream(
    String chatId,
  ) {
    return FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
      final decryptedMessages = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isDeleted'] == true) {
          decryptedMessages.add({
            'id': doc.id,
            'text': '[Deleted]',
            'senderId': data['senderId'],
            'createdAt': data['createdAt'],
            'isDeleted': true,
          });
          continue;
        }

        final encryptedText = data['encryptedText'] as String?;
        final iv = data['iv'] as String?;

        if (encryptedText != null && iv != null) {
          final decrypted = await decryptMessage(chatId, encryptedText, iv);
          decryptedMessages.add({
            'id': doc.id,
            'text': decrypted ?? '[Decryption failed]',
            'senderId': data['senderId'],
            'createdAt': data['createdAt'],
            'isDeleted': false,
          });
        }
      }

      return decryptedMessages;
    });
  }

  /// Delete a secret chat (including all messages and local key).
  Future<void> deleteSecretChat({
    required String chatId,
    required String currentUid,
  }) async {
    // Delete local key
    await deleteKey(chatId);

    // Remove from user's secretChats array
    await FirebaseService.firestore
        .collection('users')
        .doc(currentUid)
        .update({
      'secretChats': FieldValue.arrayRemove([chatId]),
    }).catchError((_) {});

    // Delete all messages (batch)
    final messages = await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = FirebaseService.firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Delete the chat document
    await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .delete();
  }
}
