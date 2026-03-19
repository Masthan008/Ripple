import 'package:cloud_firestore/cloud_firestore.dart';

/// Reply data embedded in a message
class ReplyData {
  final String messageId;
  final String senderName;
  final String text;
  final String type;
  final String? mediaUrl;

  const ReplyData({
    required this.messageId,
    required this.senderName,
    required this.text,
    required this.type,
    this.mediaUrl,
  });

  factory ReplyData.fromMap(Map<String, dynamic> map) {
    return ReplyData(
      messageId: map['messageId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      text: map['text'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      mediaUrl: map['mediaUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'messageId': messageId,
        'senderName': senderName,
        'text': text,
        'type': type,
        'mediaUrl': mediaUrl,
      };
}

/// Message model — Phase 1 with reactions, reply, edit, delete, pin, star, seen
class MessageModel {
  final String id;
  final String senderId;
  final String? text;
  final String type; // text|image|video|file|voice|gif|emoji
  final String? mediaUrl;
  final String? fileName;

  // Phase 1 fields
  final Map<String, List<String>> reactions;
  final ReplyData? replyTo;
  final bool isEdited;
  final bool isDeleted;
  final bool isPinned;
  final bool isStarred;
  final bool isForwarded;
  final List<String> starredBy;
  final List<String> deletedFor;
  final List<String> seenBy;
  final DateTime createdAt;
  final DateTime? editedAt;
  final Timestamp? deleteAt;
  final Timestamp? expiresAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    this.text,
    this.type = 'text',
    this.mediaUrl,
    this.fileName,
    this.reactions = const {},
    this.replyTo,
    this.isEdited = false,
    this.isDeleted = false,
    this.isPinned = false,
    this.isStarred = false,
    this.isForwarded = false,
    this.starredBy = const [],
    this.deletedFor = const [],
    this.seenBy = const [],
    required this.createdAt,
    this.editedAt,
    this.deleteAt,
    this.expiresAt,
  });

  factory MessageModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Parse reactions map safely
    final rawReactions =
        data['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = rawReactions.map((key, value) =>
        MapEntry(key, List<String>.from(value as List)));

    // Parse replyTo safely
    ReplyData? replyTo;
    if (data['replyTo'] != null) {
      replyTo =
          ReplyData.fromMap(data['replyTo'] as Map<String, dynamic>);
    }

    // Support both 'createdAt' and legacy 'timestamp' field
    DateTime createdAt;
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['timestamp'] != null &&
        data['timestamp'] is Timestamp) {
      createdAt = (data['timestamp'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String?,
      type: data['type'] as String? ?? 'text',
      mediaUrl: data['mediaUrl'] as String?,
      fileName: data['fileName'] as String?,
      reactions: reactions,
      replyTo: replyTo,
      isEdited: data['isEdited'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      isPinned: data['isPinned'] as bool? ?? false,
      isStarred: data['isStarred'] as bool? ?? false,
      isForwarded: data['isForwarded'] as bool? ?? false,
      starredBy:
          List<String>.from(data['starredBy'] as List? ?? []),
      deletedFor:
          List<String>.from(data['deletedFor'] as List? ?? []),
      seenBy: List<String>.from(data['seenBy'] as List? ?? []),
      createdAt: createdAt,
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      deleteAt: data['deleteAt'] as Timestamp?,
      expiresAt: data['expiresAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'reactions': reactions,
      'replyTo': replyTo?.toMap(),
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'isPinned': isPinned,
      'isStarred': isStarred,
      'isForwarded': isForwarded,
      'starredBy': starredBy,
      'deletedFor': deletedFor,
      'seenBy': seenBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt':
          editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'deleteAt': deleteAt,
      'expiresAt': expiresAt,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    String? type,
    String? mediaUrl,
    String? fileName,
    Map<String, List<String>>? reactions,
    ReplyData? replyTo,
    bool? isEdited,
    bool? isDeleted,
    bool? isPinned,
    bool? isStarred,
    bool? isForwarded,
    List<String>? starredBy,
    List<String>? deletedFor,
    List<String>? seenBy,
    DateTime? createdAt,
    DateTime? editedAt,
    Timestamp? deleteAt,
    Timestamp? expiresAt,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      fileName: fileName ?? this.fileName,
      reactions: reactions ?? this.reactions,
      replyTo: replyTo ?? this.replyTo,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
      isForwarded: isForwarded ?? this.isForwarded,
      starredBy: starredBy ?? this.starredBy,
      deletedFor: deletedFor ?? this.deletedFor,
      seenBy: seenBy ?? this.seenBy,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deleteAt: deleteAt ?? this.deleteAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  bool get isTextMessage => type == 'text' || type == 'emoji';
  bool get isMediaMessage => type == 'image' || type == 'video';
  bool get isFileMessage => type == 'file';
}
