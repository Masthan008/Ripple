import 'package:cloud_firestore/cloud_firestore.dart';

/// Group model matching Firestore groups/{groupId} schema — PRD §8.3 & Telegram Parity
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
  final List<String> bannedMembers;
  final Map<String, dynamic> mutedMembers;
  final int slowModeSeconds;
  final bool requiresApproval;
  final Map<String, Map<String, bool>> adminPermissions;
  final bool onlyAdminsCanMessage;

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
    this.bannedMembers = const [],
    this.mutedMembers = const {},
    this.slowModeSeconds = 0,
    this.requiresApproval = false,
    this.adminPermissions = const {},
    this.onlyAdminsCanMessage = false,
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
      bannedMembers: List<String>.from(data['bannedMembers'] ?? []),
      mutedMembers: Map<String, dynamic>.from(data['mutedMembers'] ?? {}),
      slowModeSeconds: (data['slowModeSeconds'] as num?)?.toInt() ?? 0,
      requiresApproval: data['requiresApproval'] == true,
      adminPermissions: (data['adminPermissions'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, Map<String, bool>.from(v as Map)),
      ) ?? {},
      onlyAdminsCanMessage: data['onlyAdminsCanMessage'] == true,
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
      'bannedMembers': bannedMembers,
      'mutedMembers': mutedMembers,
      'slowModeSeconds': slowModeSeconds,
      'requiresApproval': requiresApproval,
      'adminPermissions': adminPermissions,
      'onlyAdminsCanMessage': onlyAdminsCanMessage,
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
    List<String>? bannedMembers,
    Map<String, dynamic>? mutedMembers,
    int? slowModeSeconds,
    bool? requiresApproval,
    Map<String, Map<String, bool>>? adminPermissions,
    bool? onlyAdminsCanMessage,
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
      bannedMembers: bannedMembers ?? this.bannedMembers,
      mutedMembers: mutedMembers ?? this.mutedMembers,
      slowModeSeconds: slowModeSeconds ?? this.slowModeSeconds,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      adminPermissions: adminPermissions ?? this.adminPermissions,
      onlyAdminsCanMessage: onlyAdminsCanMessage ?? this.onlyAdminsCanMessage,
    );
  }

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);
  bool get isCreator => createdBy == id;
  int get memberCount => members.length;

  bool isBanned(String uid) => bannedMembers.contains(uid);

  bool isMuted(String uid) {
    if (!mutedMembers.containsKey(uid)) return false;
    final val = mutedMembers[uid];
    if (val == 'always') return true;
    if (val is String) {
      final expiry = DateTime.tryParse(val);
      if (expiry != null && expiry.isAfter(DateTime.now())) return true;
    }
    return false;
  }

  bool canAdmin(String uid, String permissionKey) {
    if (uid == createdBy) return true;
    if (!admins.contains(uid)) return false;
    final perms = adminPermissions[uid];
    if (perms == null) return true; // Default admin has all rights unless restricted
    return perms[permissionKey] ?? true;
  }
}
