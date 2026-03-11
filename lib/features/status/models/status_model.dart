import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single status/story in the Ripple app.
/// Stored in the `statuses` Firestore collection.
/// Auto-expires after 24 hours.
class StatusModel {
  final String statusId;
  final String uid;
  final String ownerName;
  final String ownerPhoto;
  final String type; // photo | video | text | mood
  final String? mediaUrl;
  final String? text;
  final List<String>? gradientColors;
  final String? mood; // happy | focused | busy | gaming | vibing
  final List<Map<String, dynamic>> viewers;
  final Map<String, String> reactions; // { uid: emoji }
  final String privacy; // everyone | friends | custom
  final List<String> customViewers;
  final Timestamp expiresAt;
  final Timestamp createdAt;

  const StatusModel({
    required this.statusId,
    required this.uid,
    required this.ownerName,
    required this.ownerPhoto,
    required this.type,
    this.mediaUrl,
    this.text,
    this.gradientColors,
    this.mood,
    this.viewers = const [],
    this.reactions = const {},
    this.privacy = 'friends',
    this.customViewers = const [],
    required this.expiresAt,
    required this.createdAt,
  });

  factory StatusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StatusModel(
      statusId: doc.id,
      uid: data['uid'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      ownerPhoto: data['ownerPhoto'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      mediaUrl: data['mediaUrl'] as String?,
      text: data['text'] as String?,
      gradientColors: data['gradientColors'] != null
          ? List<String>.from(data['gradientColors'] as List)
          : null,
      mood: data['mood'] as String?,
      viewers: (data['viewers'] as List? ?? [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      reactions:
          Map<String, String>.from(data['reactions'] as Map? ?? {}),
      privacy: data['privacy'] as String? ?? 'friends',
      customViewers:
          List<String>.from(data['customViewers'] as List? ?? []),
      expiresAt:
          data['expiresAt'] as Timestamp? ?? Timestamp.now(),
      createdAt:
          data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'ownerName': ownerName,
        'ownerPhoto': ownerPhoto,
        'type': type,
        'mediaUrl': mediaUrl,
        'text': text,
        'gradientColors': gradientColors,
        'mood': mood,
        'viewers': viewers,
        'reactions': reactions,
        'privacy': privacy,
        'customViewers': customViewers,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
      };

  bool get isExpired => DateTime.now().isAfter(expiresAt.toDate());
}
