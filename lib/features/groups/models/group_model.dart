import 'package:cloud_firestore/cloud_firestore.dart';

/// Group model matching Firestore groups/{groupId} schema — PRD §8.3
class GroupModel {
  final String id;
  final String name;
  final String? description;
  final String? photoUrl;
  final String createdBy;
  final List<String> members;
  final List<String> admins;
  final DateTime createdAt;
  final Map<String, dynamic>? lastMessage;
  final Map<String, int> unreadCount;

  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    this.photoUrl,
    required this.createdBy,
    required this.members,
    required this.admins,
    required this.createdAt,
    this.lastMessage,
    this.unreadCount = const {},
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
      admins: List<String>.from(data['admins'] ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: data['lastMessage'] as Map<String, dynamic>?,
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'members': members,
      'admins': admins,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
    };
  }

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? photoUrl,
    String? createdBy,
    List<String>? members,
    List<String>? admins,
    DateTime? createdAt,
    Map<String, dynamic>? lastMessage,
    Map<String, int>? unreadCount,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      photoUrl: photoUrl ?? this.photoUrl,
      createdBy: createdBy ?? this.createdBy,
      members: members ?? this.members,
      admins: admins ?? this.admins,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);
  bool get isCreator => createdBy == id;
  int get memberCount => members.length;
}
