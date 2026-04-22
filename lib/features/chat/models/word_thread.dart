import 'package:cloud_firestore/cloud_firestore.dart';

/// WordThread — Holographic Word-Threads™
///
/// A micro-thread attached to a specific word within a message.
/// Users can long-press any word to "tear open a rift" and start
/// a tiny ephemeral conversation attached to that word.
///
/// Word threads dissolve after 24 hours to keep the main chat clean.
class WordThread {
  /// The word index in the message text.
  final int wordIndex;

  /// The actual word that was tapped.
  final String word;

  /// List of mini-messages in this thread.
  final List<MiniMessage> messages;

  /// When the rift was opened.
  final DateTime createdAt;

  /// Expiration time (24 hours from creation).
  final DateTime expiresAt;

  const WordThread({
    required this.wordIndex,
    required this.word,
    required this.messages,
    required this.createdAt,
    required this.expiresAt,
  });

  factory WordThread.fromMap(Map<String, dynamic> map) {
    return WordThread(
      wordIndex: map['wordIndex'] as int? ?? 0,
      word: map['word'] as String? ?? '',
      messages: (map['messages'] as List? ?? [])
          .map((m) => MiniMessage.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(hours: 24)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wordIndex': wordIndex,
      'word': word,
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  /// Check if this thread has expired (24 hours).
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Create a new thread with a message added.
  WordThread addMessage(MiniMessage msg) {
    return WordThread(
      wordIndex: wordIndex,
      word: word,
      messages: [...messages, msg],
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

/// A tiny message within a word thread.
class MiniMessage {
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const MiniMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  factory MiniMessage.fromMap(Map<String, dynamic> map) {
    return MiniMessage(
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
