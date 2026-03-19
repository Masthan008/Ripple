import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a poll in a group chat.
class PollModel {
  final String question;
  final List<String> options;
  /// Map of option index -> list of user IDs who voted for it
  final Map<String, List<String>> votes;
  final Timestamp createdAt;
  final Timestamp? expiresAt;
  final String creatorId;

  const PollModel({
    required this.question,
    required this.options,
    required this.votes,
    required this.createdAt,
    this.expiresAt,
    required this.creatorId,
  });

  factory PollModel.fromMap(Map<String, dynamic> map) {
    // Convert dynamic map cleanly into expected types
    final rawVotes = map['votes'] as Map<String, dynamic>? ?? {};
    final parsedVotes = <String, List<String>>{};
    
    rawVotes.forEach((key, value) {
      if (value is List) {
        parsedVotes[key] = value.cast<String>();
      }
    });

    return PollModel(
      question: map['question'] as String? ?? 'Untitled Poll',
      options: List<String>.from(map['options'] ?? []),
      votes: parsedVotes,
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      expiresAt: map['expiresAt'] as Timestamp?,
      creatorId: map['creatorId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'votes': votes,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'creatorId': creatorId,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.toDate().isBefore(DateTime.now());
  }

  int get totalVotes {
    return votes.values.fold(0, (sum, users) => sum + users.length);
  }

  bool hasVoted(String userId) {
    return votes.values.any((users) => users.contains(userId));
  }
}
