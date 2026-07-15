import 'package:cloud_firestore/cloud_firestore.dart';

import 'emotional_signature.dart';

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
  final String type; // text|image|video|file|voice|gif|emoji|sticker|poll
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

  // Action items extracted by AI
  final List<String>? actionItems;
  final Timestamp? expiresAt;

  // Emotional Resonance™ — typing rhythm/intensity metadata
  final EmotionalSignature? emotionalSignature;

  // Chronos Messaging™ — contextual time-capsule unlock conditions
  final String? chronosConditionType;   // 'location', 'weather', 'battery', 'time'
  final String? chronosConditionValue;  // geo-json, 'rain', '10', ISO-8601
  final bool isChronosLocked;

  // Ambient Sonic Footprints™ — 2-second ambient audio snapshot
  final String? ambientAudioUrl;

  // Quantum Vault™ — biometric scrambled messages
  final bool isQuantumLocked;

  // Spatial Threads™ — canvas position for group chat canvas mode
  final double? canvasX;
  final double? canvasY;

  // Sonic Whispers™ — cached voice transcription
  final String? voiceTranscription;

  // View-Once Media
  final bool isViewOnce;
  final List<String> viewedBy;

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
    this.actionItems,
    this.emotionalSignature,
    this.chronosConditionType,
    this.chronosConditionValue,
    this.isChronosLocked = false,
    this.ambientAudioUrl,
    this.isQuantumLocked = false,
    this.canvasX,
    this.canvasY,
    this.voiceTranscription,
    this.isViewOnce = false,
    this.viewedBy = const [],
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
      actionItems: data['actionItems'] is List
          ? List<String>.from(data['actionItems'] as List)
          : null,
      emotionalSignature: data['emotionalSignature'] != null
          ? EmotionalSignature.fromMap(
              data['emotionalSignature'] as Map<String, dynamic>)
          : null,
      chronosConditionType: data['chronosConditionType'] as String?,
      chronosConditionValue: data['chronosConditionValue'] as String?,
      isChronosLocked: data['isChronosLocked'] as bool? ?? false,
      ambientAudioUrl: data['ambientAudioUrl'] as String?,
      isQuantumLocked: data['isQuantumLocked'] as bool? ?? false,
      canvasX: (data['canvasX'] as num?)?.toDouble(),
      canvasY: (data['canvasY'] as num?)?.toDouble(),
      voiceTranscription: data['voiceTranscription'] as String?,
      isViewOnce: data['isViewOnce'] as bool? ?? false,
      viewedBy: List<String>.from(data['viewedBy'] as List? ?? []),
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
      'emotionalSignature': emotionalSignature?.toMap(),
      'chronosConditionType': chronosConditionType,
      'chronosConditionValue': chronosConditionValue,
      'isChronosLocked': isChronosLocked,
      'ambientAudioUrl': ambientAudioUrl,
      'isQuantumLocked': isQuantumLocked,
      if (canvasX != null) 'canvasX': canvasX,
      if (canvasY != null) 'canvasY': canvasY,
      if (voiceTranscription != null) 'voiceTranscription': voiceTranscription,
      'isViewOnce': isViewOnce,
      'viewedBy': viewedBy,
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
    EmotionalSignature? emotionalSignature,
    String? chronosConditionType,
    String? chronosConditionValue,
    bool? isChronosLocked,
    String? ambientAudioUrl,
    bool? isQuantumLocked,
    double? canvasX,
    double? canvasY,
    String? voiceTranscription,
    bool? isViewOnce,
    List<String>? viewedBy,
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
      emotionalSignature: emotionalSignature ?? this.emotionalSignature,
      chronosConditionType: chronosConditionType ?? this.chronosConditionType,
      chronosConditionValue: chronosConditionValue ?? this.chronosConditionValue,
      isChronosLocked: isChronosLocked ?? this.isChronosLocked,
      ambientAudioUrl: ambientAudioUrl ?? this.ambientAudioUrl,
      isQuantumLocked: isQuantumLocked ?? this.isQuantumLocked,
      canvasX: canvasX ?? this.canvasX,
      canvasY: canvasY ?? this.canvasY,
      voiceTranscription: voiceTranscription ?? this.voiceTranscription,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedBy: viewedBy ?? this.viewedBy,
    );
  }

  bool get isTextMessage => type == 'text' || type == 'emoji';
  bool get isMediaMessage => type == 'image' || type == 'video' || type == 'circular_video';
  bool get isFileMessage => type == 'file';
  bool get isStickerMessage => type == 'sticker';
}
