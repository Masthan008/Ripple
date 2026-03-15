import 'package:cloud_firestore/cloud_firestore.dart';

/// Group model matching Firestore groups/{groupId} schema — PRD §8.3
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String createdBy;
  final List<String> members;
  final List<String> memberIds;
  final List<String> admins;
  final DateTime createdAt;
  final Map<String, dynamic>? lastMessage;
  final Map<String, int> unreadCount;
  final Map<String, Map<String, dynamic>> memberPermissions;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.createdBy,
    required this.members,
    this.memberIds = const [],
    required this.admins,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = const {},
    this.memberPermissions = const {},
  });

  factory GroupModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GroupModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      photoUrl: data['photoUrl'],
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? data['members'] ?? []),
      admins: List<String>.from(data['admins'] ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: () {
        final lm = data['lastMessage'];
        if (lm is Map) return Map<String, dynamic>.from(lm);
        if (lm is String) return <String, dynamic>{'text': lm, 'type': 'text'};
        return null;
      }(),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      memberPermissions: (data['memberPermissions'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      ) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'members': members,
      'memberIds': memberIds,
      'admins': admins,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
      'memberPermissions': memberPermissions,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? photoUrl,
    String? createdBy,
    List<String>? members,
    List<String>? memberIds,
    List<String>? admins,
    DateTime? createdAt,
    Map<String, dynamic>? lastMessage,
    Map<String, int>? unreadCount,
    Map<String, Map<String, dynamic>>? memberPermissions,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      memberIds: memberIds ?? this.memberIds,
      admins: admins ?? this.admins,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      memberPermissions: memberPermissions ?? this.memberPermissions,
    );
  }

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);
  bool get isCreator => createdBy == id;
  int get memberCount => members.length;
}
