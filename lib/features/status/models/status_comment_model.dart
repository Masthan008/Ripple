import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a single comment or reply on a Status.
/// Stored in `statuses/{statusId}/comments/{commentId}`.
class StatusCommentModel {
  final String commentId;
  final String uid;
  final String name;
  final String photoUrl;
  final String text;
  final String type; // 'text' | 'emoji' | 'reply'
  final Timestamp createdAt;

  const StatusCommentModel({
    required this.commentId,
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.text,
    this.type = 'text',
    required this.createdAt,
  });

  factory StatusCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return StatusCommentModel(
      commentId: doc.id,
      uid: data['uid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      photoUrl: data['photoUrl'] as String? ?? '',
      text: data['text'] as String? ?? '',
      type: data['type'] as String? ?? 'text',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'name': name,
        'photoUrl': photoUrl,
        'text': text,
        'type': type,
        'createdAt': createdAt,
      };
}
