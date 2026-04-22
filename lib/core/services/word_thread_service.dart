import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/chat/models/word_thread.dart';

/// Word Thread Service — Holographic Word-Threads™
///
/// Manages CRUD operations for word threads in Firestore.
/// Word threads are stored in a sub-collection under each message:
/// `chats/{chatId}/messages/{messageId}/wordThreads/{wordIndex}`
///
/// Threads auto-expire after 24 hours. Expired threads are cleaned
/// up lazily on read.
class WordThreadService {
  WordThreadService._();
  static final WordThreadService instance = WordThreadService._();

  final _firestore = FirebaseFirestore.instance;

  /// Create or open a word thread for a specific word in a message.
  Future<WordThread> openThread({
    required String chatId,
    required String messageId,
    required int wordIndex,
    required String word,
    required bool isGroup,
  }) async {
    final collection = isGroup ? 'groups' : 'chats';
    final threadRef = _firestore
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('wordThreads')
        .doc(wordIndex.toString());

    final doc = await threadRef.get();

    if (doc.exists) {
      final thread = WordThread.fromMap(doc.data()!);
      if (!thread.isExpired) return thread;
      // Expired — delete and create fresh
      await threadRef.delete();
    }

    // Create new thread
    final now = DateTime.now();
    final thread = WordThread(
      wordIndex: wordIndex,
      word: word,
      messages: [],
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );

    await threadRef.set(thread.toMap());
    return thread;
  }

  /// Add a mini-message to a word thread.
  Future<void> addMessage({
    required String chatId,
    required String messageId,
    required int wordIndex,
    required MiniMessage message,
    required bool isGroup,
  }) async {
    final collection = isGroup ? 'groups' : 'chats';
    final threadRef = _firestore
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('wordThreads')
        .doc(wordIndex.toString());

    await threadRef.update({
      'messages': FieldValue.arrayUnion([message.toMap()]),
    });

    debugPrint('🌌 Word thread message added: $wordIndex');
  }

  /// Stream word threads for a specific message.
  Stream<List<WordThread>> streamThreads({
    required String chatId,
    required String messageId,
    required bool isGroup,
  }) {
    final collection = isGroup ? 'groups' : 'chats';
    return _firestore
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('wordThreads')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WordThread.fromMap(doc.data()))
          .where((thread) => !thread.isExpired)
          .toList();
    });
  }

  /// Get active thread count for a message (for badge display).
  Future<int> getActiveThreadCount({
    required String chatId,
    required String messageId,
    required bool isGroup,
  }) async {
    final collection = isGroup ? 'groups' : 'chats';
    final snapshot = await _firestore
        .collection(collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .collection('wordThreads')
        .get();

    return snapshot.docs
        .map((doc) => WordThread.fromMap(doc.data()))
        .where((thread) => !thread.isExpired)
        .length;
  }
}
