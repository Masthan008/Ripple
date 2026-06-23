import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:cryptography/cryptography.dart' as crypto2;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_service.dart';

/// Secret Chat Service — Automated End-to-End Encrypted Messaging
///
/// Provides Curve25519 X3DH automated key handshakes and
/// AES-256-GCM authenticated encryption for secret messaging.
/// Private keys are kept exclusively on-device in secure storage.
class SecretChatService {
  SecretChatService._();
  static final SecretChatService instance = SecretChatService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static final _x25519 = crypto2.X25519();

  // ─── Prekey Management (X3DH Setup) ──────────────────────

  /// Check and generate the Curve25519 E2EE prekey bundle for the user.
  /// Publishes public keys to Firestore and saves private keys in Secure Storage.
  Future<void> ensureUserPrekeys(String uid) async {
    final hasIK = await _storage.containsKey(key: 'e2ee_ik_private_$uid');
    if (hasIK) {
      final doc = await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('prekeys')
          .doc('bundle')
          .get();
      if (doc.exists) {
        return; // Already initialized and published
      }
    }

    debugPrint('🔐 SecretChat: Generating Curve25519 prekey bundle for $uid...');

    try {
      // 1. Generate Identity Key (IK)
      final ikKeyPair = await _x25519.newKeyPair();
      final ikPublic = await ikKeyPair.extractPublicKey();
      final ikPrivate = await ikKeyPair.extractPrivateKeyBytes();

      // 2. Generate Signed Prekey (SPK)
      final spkKeyPair = await _x25519.newKeyPair();
      final spkPublic = await spkKeyPair.extractPublicKey();
      final spkPrivate = await spkKeyPair.extractPrivateKeyBytes();

      // 3. Generate 5 One-Time Prekeys (OPK)
      final opkPubs = <String>[];
      final opkPrivates = <String>[];
      for (int i = 0; i < 5; i++) {
        final opkKeyPair = await _x25519.newKeyPair();
        final opkPublic = await opkKeyPair.extractPublicKey();
        final opkPrivate = await opkKeyPair.extractPrivateKeyBytes();

        opkPubs.add(base64.encode(opkPublic.bytes));
        opkPrivates.add(base64.encode(opkPrivate));
      }

      // 4. Save Private Keys Locally
      await _storage.write(key: 'e2ee_ik_private_$uid', value: base64.encode(ikPrivate));
      await _storage.write(key: 'e2ee_ik_public_$uid', value: base64.encode(ikPublic.bytes));
      await _storage.write(key: 'e2ee_spk_private_$uid', value: base64.encode(spkPrivate));
      await _storage.write(key: 'e2ee_spk_public_$uid', value: base64.encode(spkPublic.bytes));
      await _storage.write(key: 'e2ee_opk_privates_$uid', value: jsonEncode(opkPrivates));

      // 5. Upload Public Keys
      await FirebaseService.firestore
          .collection('users')
          .doc(uid)
          .collection('prekeys')
          .doc('bundle')
          .set({
        'uid': uid,
        'identityKey': base64.encode(ikPublic.bytes),
        'signedPrekey': base64.encode(spkPublic.bytes),
        'oneTimePrekeys': opkPubs,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🔐 SecretChat: Published E2EE prekey bundle for $uid');
    } catch (e) {
      debugPrint('❌ ensureUserPrekeys generation failed: $e');
    }
  }

  // ─── Handshake Operations (X3DH Protocol) ─────────────────

  /// Alice (Initiator) performs X3DH key agreement and uploads handshake parameters.
  Future<void> performInitiatorHandshake({
    required String chatId,
    required String currentUid,
    required String partnerUid,
  }) async {
    try {
      // Ensure Alice's own prekeys exist
      await ensureUserPrekeys(currentUid);

      // 1. Fetch Bob's prekey bundle
      final bobDoc = await FirebaseService.firestore
          .collection('users')
          .doc(partnerUid)
          .collection('prekeys')
          .doc('bundle')
          .get();

      if (!bobDoc.exists) {
        debugPrint('⚠️ SecretChat: Bob ($partnerUid) has no prekey bundle. Using legacy AES fallback.');
        await generateAndStoreKey(chatId);
        return;
      }

      final bobData = bobDoc.data()!;
      final bobIkBytes = base64.decode(bobData['identityKey'] as String);
      final bobSpkBytes = base64.decode(bobData['signedPrekey'] as String);
      final bobOpks = List<String>.from(bobData['oneTimePrekeys'] as List? ?? []);

      // 2. Load Alice's Identity Private/Public Keys
      final aliceIkPrivate = await _storage.read(key: 'e2ee_ik_private_$currentUid');
      final aliceIkPublic = await _storage.read(key: 'e2ee_ik_public_$currentUid');
      if (aliceIkPrivate == null || aliceIkPublic == null) {
        throw Exception('Alice identity keys missing from storage');
      }

      final aliceIkKeyPair = crypto2.SimpleKeyPairData(
        base64.decode(aliceIkPrivate),
        publicKey: crypto2.SimplePublicKey(base64.decode(aliceIkPublic), type: crypto2.KeyPairType.x25519),
        type: crypto2.KeyPairType.x25519,
      );

      // 3. Generate Ephemeral Key (EK)
      final ekKeyPair = await _x25519.newKeyPair();
      final ekPublic = await ekKeyPair.extractPublicKey();

      // 4. Calculate DH Shared Secrets
      final bobIkPub = crypto2.SimplePublicKey(bobIkBytes, type: crypto2.KeyPairType.x25519);
      final bobSpkPub = crypto2.SimplePublicKey(bobSpkBytes, type: crypto2.KeyPairType.x25519);

      // DH1 = DH(IK_Alice, SPK_Bob)
      final dh1Secret = await _x25519.sharedSecretKey(keyPair: aliceIkKeyPair, remotePublicKey: bobSpkPub);
      final dh1 = await dh1Secret.extractBytes();

      // DH2 = DH(EK_Alice, IK_Bob)
      final dh2Secret = await _x25519.sharedSecretKey(keyPair: ekKeyPair, remotePublicKey: bobIkPub);
      final dh2 = await dh2Secret.extractBytes();

      // DH3 = DH(EK_Alice, SPK_Bob)
      final dh3Secret = await _x25519.sharedSecretKey(keyPair: ekKeyPair, remotePublicKey: bobSpkPub);
      final dh3 = await dh3Secret.extractBytes();

      // DH4 = DH(EK_Alice, OPK_Bob) (optional)
      List<int>? dh4;
      int? consumedOpkIndex;
      if (bobOpks.isNotEmpty) {
        consumedOpkIndex = 0;
        final bobOpkBytes = base64.decode(bobOpks[0]);
        final bobOpkPub = crypto2.SimplePublicKey(bobOpkBytes, type: crypto2.KeyPairType.x25519);
        final dh4Secret = await _x25519.sharedSecretKey(keyPair: ekKeyPair, remotePublicKey: bobOpkPub);
        dh4 = await dh4Secret.extractBytes();
      }

      // 5. Concatenate and derive master key via SHA-256
      final builder = BytesBuilder();
      builder.add(dh1);
      builder.add(dh2);
      builder.add(dh3);
      if (dh4 != null) {
        builder.add(dh4);
      }

      final sha = crypto.sha256.convert(builder.toBytes());
      final masterKeyBytes = sha.bytes;

      // 6. Save derived master key
      await _storage.write(
        key: 'secret_chat_key_$chatId',
        value: base64.encode(masterKeyBytes),
      );

      // 7. Publish handshake metadata to Firestore
      await FirebaseService.firestore
          .collection('secretChats')
          .doc(chatId)
          .collection('handshake')
          .doc('init')
          .set({
        'initiatorId': currentUid,
        'initiatorIk': aliceIkPublic,
        'initiatorEk': base64.encode(ekPublic.bytes),
        'consumedOpkIndex': consumedOpkIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🔐 SecretChat: Handshake initialized by Alice for $chatId');
    } catch (e) {
      debugPrint('❌ performInitiatorHandshake failed: $e');
      // Fallback to static generation
      await generateAndStoreKey(chatId);
    }
  }

  /// Bob (Recipient) resolves X3DH handshake to compute the identical master key.
  Future<void> ensureHandshakeComplete(String chatId, String currentUid) async {
    if (await hasKey(chatId)) return;

    try {
      final hsDoc = await FirebaseService.firestore
          .collection('secretChats')
          .doc(chatId)
          .collection('handshake')
          .doc('init')
          .get();

      if (!hsDoc.exists) return;

      final hsData = hsDoc.data()!;
      final initiatorId = hsData['initiatorId'] as String;
      if (initiatorId == currentUid) return; // Initiator already generated the key

      final aliceIkBytes = base64.decode(hsData['initiatorIk'] as String);
      final aliceEkBytes = base64.decode(hsData['initiatorEk'] as String);
      final consumedOpkIndex = hsData['consumedOpkIndex'] as int?;

      // Ensure Bob has generated local prekeys
      await ensureUserPrekeys(currentUid);

      // Load Bob's private keys
      final bobIkPrivate = await _storage.read(key: 'e2ee_ik_private_$currentUid');
      final bobIkPublic = await _storage.read(key: 'e2ee_ik_public_$currentUid');
      final bobSpkPrivate = await _storage.read(key: 'e2ee_spk_private_$currentUid');
      final bobSpkPublic = await _storage.read(key: 'e2ee_spk_public_$currentUid');
      final bobOpkPrivates = await _storage.read(key: 'e2ee_opk_privates_$currentUid');

      if (bobIkPrivate == null || bobIkPublic == null ||
          bobSpkPrivate == null || bobSpkPublic == null) {
        throw Exception('Bob private keys missing from storage');
      }

      final bobIkKeyPair = crypto2.SimpleKeyPairData(
        base64.decode(bobIkPrivate),
        publicKey: crypto2.SimplePublicKey(base64.decode(bobIkPublic), type: crypto2.KeyPairType.x25519),
        type: crypto2.KeyPairType.x25519,
      );

      final bobSpkKeyPair = crypto2.SimpleKeyPairData(
        base64.decode(bobSpkPrivate),
        publicKey: crypto2.SimplePublicKey(base64.decode(bobSpkPublic), type: crypto2.KeyPairType.x25519),
        type: crypto2.KeyPairType.x25519,
      );

      final aliceIkPub = crypto2.SimplePublicKey(aliceIkBytes, type: crypto2.KeyPairType.x25519);
      final aliceEkPub = crypto2.SimplePublicKey(aliceEkBytes, type: crypto2.KeyPairType.x25519);

      // DH1 = DH(SPK_Bob, IK_Alice)
      final dh1Secret = await _x25519.sharedSecretKey(keyPair: bobSpkKeyPair, remotePublicKey: aliceIkPub);
      final dh1 = await dh1Secret.extractBytes();

      // DH2 = DH(IK_Bob, EK_Alice)
      final dh2Secret = await _x25519.sharedSecretKey(keyPair: bobIkKeyPair, remotePublicKey: aliceEkPub);
      final dh2 = await dh2Secret.extractBytes();

      // DH3 = DH(SPK_Bob, EK_Alice)
      final dh3Secret = await _x25519.sharedSecretKey(keyPair: bobSpkKeyPair, remotePublicKey: aliceEkPub);
      final dh3 = await dh3Secret.extractBytes();

      // DH4 = DH(OPK_Bob, EK_Alice)
      List<int>? dh4;
      if (consumedOpkIndex != null && bobOpkPrivates != null) {
        final List<dynamic> opkPrivatesList = jsonDecode(bobOpkPrivates);
        if (consumedOpkIndex < opkPrivatesList.length) {
          final opkPrivateBytes = base64.decode(opkPrivatesList[consumedOpkIndex] as String);
          // Fetch corresponding public key from Firestore to match SimpleKeyPairData expectations
          final myBundle = await FirebaseService.firestore
              .collection('users')
              .doc(currentUid)
              .collection('prekeys')
              .doc('bundle')
              .get();
          
          if (myBundle.exists) {
            final opkPubs = List<String>.from(myBundle.data()?['oneTimePrekeys'] as List? ?? []);
            final opkPublicBytes = base64.decode(opkPubs[consumedOpkIndex]);
            
            final bobOpkKeyPair = crypto2.SimpleKeyPairData(
              opkPrivateBytes,
              publicKey: crypto2.SimplePublicKey(opkPublicBytes, type: crypto2.KeyPairType.x25519),
              type: crypto2.KeyPairType.x25519,
            );
            final dh4Secret = await _x25519.sharedSecretKey(keyPair: bobOpkKeyPair, remotePublicKey: aliceEkPub);
            dh4 = await dh4Secret.extractBytes();
          }
        }
      }

      // Derive Bob's master key bytes
      final builder = BytesBuilder();
      builder.add(dh1);
      builder.add(dh2);
      builder.add(dh3);
      if (dh4 != null) {
        builder.add(dh4);
      }

      final sha = crypto.sha256.convert(builder.toBytes());
      final masterKeyBytes = sha.bytes;

      // Save derived master key
      await _storage.write(
        key: 'secret_chat_key_$chatId',
        value: base64.encode(masterKeyBytes),
      );

      debugPrint('🔐 SecretChat: Handshake resolved by Bob for $chatId');
    } catch (e) {
      debugPrint('❌ ensureHandshakeComplete failed: $e');
    }
  }

  // ─── Symmetric Key Management ──────────────────────────────

  /// Generate and store a new AES-256 key for a secret chat (legacy/fallback).
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
    // Clear Firestore handshake
    await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .collection('handshake')
        .doc('init')
        .delete()
        .catchError((_) {});
  }

  /// Export the key as a base64 string.
  Future<String?> exportKey(String chatId) async {
    return await _storage.read(key: 'secret_chat_key_$chatId');
  }

  /// Import a key from a base64 string.
  Future<void> importKey(String chatId, String base64Key) async {
    await _storage.write(
      key: 'secret_chat_key_$chatId',
      value: base64Key,
    );
  }

  // ─── Encryption / Decryption (AES-256-GCM) ─────────────────

  /// Encrypt a plaintext message using the chat's AES key in GCM mode.
  Future<Map<String, String>?> encryptMessage(
    String chatId,
    String plaintext,
  ) async {
    final key = await getKey(chatId);
    if (key == null) {
      debugPrint('❌ SecretChat: No key found for chat $chatId');
      return null;
    }

    final iv = encrypt.IV.fromSecureRandom(12); // 96-bit (12 bytes) IV for GCM
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    return {
      'encryptedText': encrypted.base64,
      'iv': iv.base64,
    };
  }

  /// Decrypt a ciphertext message using the chat's AES key in GCM mode.
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
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);
      return decrypted;
    } catch (e) {
      debugPrint('❌ SecretChat decryption failed (GCM): $e');
      return null;
    }
  }

  // ─── Firestore Operations ────────────────────────────────

  /// Create a new secret chat between two users.
  Future<String> createSecretChat({
    required String currentUid,
    required String partnerUid,
  }) async {
    final ids = [currentUid, partnerUid]..sort();
    final chatId = 'secret_${ids[0]}_${ids[1]}';

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

      for (final uid in [currentUid, partnerUid]) {
        await FirebaseService.firestore
            .collection('users')
            .doc(uid)
            .update({
          'secretChats': FieldValue.arrayUnion([chatId]),
        }).catchError((_) async {
          await FirebaseService.firestore
              .collection('users')
              .doc(uid)
              .set({'secretChats': [chatId]}, SetOptions(merge: true));
        });
      }
    }

    // Ensure prekeys exist for the initiator
    await ensureUserPrekeys(currentUid);

    // Initialize key exchange if we do not possess the key
    if (!await hasKey(chatId)) {
      await performInitiatorHandshake(
        chatId: chatId,
        currentUid: currentUid,
        partnerUid: partnerUid,
      );
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
    String currentUid,
  ) {
    // Attempt to automatically resolve handshake keys if Bob opens the stream
    ensureHandshakeComplete(chatId, currentUid);

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

  /// Delete a secret chat.
  Future<void> deleteSecretChat({
    required String chatId,
    required String currentUid,
  }) async {
    await deleteKey(chatId);

    await FirebaseService.firestore
        .collection('users')
        .doc(currentUid)
        .update({
      'secretChats': FieldValue.arrayRemove([chatId]),
    }).catchError((_) {});

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

    await FirebaseService.firestore
        .collection('secretChats')
        .doc(chatId)
        .delete();
  }
}
