import 'package:cloud_firestore/cloud_firestore.dart';

/// User model matching Firestore users/{uid} schema — PRD §8.1
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;
  final String bio;
  final bool isOnline;
  final DateTime? lastSeen;
  final String fcmToken;
  final String isTypingTo;
  final List<String> friends;
  final List<String> blockedUsers;
  final Map<String, List<String>> friendRequests;
  final Map<String, bool> notificationSettings;
  final Map<String, bool> privacySettings;
  final bool twoFactorEnabled;
  final int rippleScore;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.bio = '',
    this.isOnline = false,
    this.lastSeen,
    this.fcmToken = '',
    this.isTypingTo = '',
    this.friends = const [],
    this.blockedUsers = const [],
    this.friendRequests = const {'sent': [], 'received': []},
    this.notificationSettings = const {
      'messages': true,
      'groupMessages': true,
      'friendRequests': true,
      'calls': true,
      'sounds': true,
      'vibration': true,
    },
    this.privacySettings = const {
      'showOnlineStatus': true,
      'showLastSeen': true,
      'readReceipts': true,
      'allowFriendRequests': true,
    },
    this.twoFactorEnabled = false,
    this.rippleScore = 0,
  });

  /// Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      bio: data['bio'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      fcmToken: data['fcmToken'] ?? '',
      isTypingTo: data['isTypingTo'] ?? '',
      friends: List<String>.from(data['friends'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      friendRequests: {
        'sent': List<String>.from(data['friendRequests']?['sent'] ?? []),
        'received': List<String>.from(data['friendRequests']?['received'] ?? []),
      },
      notificationSettings: Map<String, bool>.from(data['notificationSettings'] ?? {}),
      privacySettings: Map<String, bool>.from(data['privacySettings'] ?? {}),
      twoFactorEnabled: data['twoFactorEnabled'] ?? false,
      rippleScore: data['rippleScore'] as int? ?? 0,
    );
  }

  /// Create from Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      bio: data['bio'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      fcmToken: data['fcmToken'] ?? '',
      isTypingTo: data['isTypingTo'] ?? '',
      friends: List<String>.from(data['friends'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      friendRequests: {
        'sent': List<String>.from(data['friendRequests']?['sent'] ?? []),
        'received': List<String>.from(data['friendRequests']?['received'] ?? []),
      },
      notificationSettings: Map<String, bool>.from(data['notificationSettings'] ?? {}),
      privacySettings: Map<String, bool>.from(data['privacySettings'] ?? {}),
      twoFactorEnabled: data['twoFactorEnabled'] ?? false,
      rippleScore: data['rippleScore'] as int? ?? 0,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'fcmToken': fcmToken,
      'isTypingTo': isTypingTo,
      'friends': friends,
      'blockedUsers': blockedUsers,
      'friendRequests': friendRequests,
      'notificationSettings': notificationSettings,
      'privacySettings': privacySettings,
      'twoFactorEnabled': twoFactorEnabled,
      'rippleScore': rippleScore,
    };
  }

  /// Copy with modified fields
  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? bio,
    bool? isOnline,
    DateTime? lastSeen,
    String? fcmToken,
    String? isTypingTo,
    List<String>? friends,
    List<String>? blockedUsers,
    Map<String, List<String>>? friendRequests,
    Map<String, bool>? notificationSettings,
    Map<String, bool>? privacySettings,
    bool? twoFactorEnabled,
    int? rippleScore,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      isTypingTo: isTypingTo ?? this.isTypingTo,
      friends: friends ?? this.friends,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      friendRequests: friendRequests ?? this.friendRequests,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      privacySettings: privacySettings ?? this.privacySettings,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      rippleScore: rippleScore ?? this.rippleScore,
    );
  }
}
