import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/models/user_model.dart';
import '../../chat/models/message_model.dart';
import '../models/group_model.dart';

const _uuid = Uuid();

// ─── My Groups Provider ──────────────────────────────────
/// Stream of groups the current user belongs to
final myGroupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.firestore
      .collection('groups')
      .where('members', arrayContains: currentUser.uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((d) => GroupModel.fromFirestore(d)).toList());
});

// ─── Group Messages Provider ─────────────────────────────
final groupMessagesProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, groupId) {
  return FirebaseService.firestore
      .collection('groups')
      .doc(groupId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((d) => MessageModel.fromFirestore(d)).toList());
});

// ─── Group Members Provider ──────────────────────────────
final groupMembersProvider =
    StreamProvider.family<List<UserModel>, String>((ref, groupId) {
  return FirebaseService.firestore
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .asyncMap((doc) async {
    if (!doc.exists) return <UserModel>[];
    final members = List<String>.from(doc.data()!['members'] ?? []);
    if (members.isEmpty) return <UserModel>[];

    final futures = members.map(
        (uid) => FirebaseService.usersCollection.doc(uid).get());
    final docs = await Future.wait(futures);
    return docs
        .where((d) => d.exists)
        .map((d) => UserModel.fromFirestore(d))
        .toList();
  });
});

// ─── Group Service ───────────────────────────────────────
final groupServiceProvider =
    Provider<GroupService>((ref) => GroupService());

class GroupService {
  final _firestore = FirebaseService.firestore;
  final _auth = FirebaseService.auth;

  String get _myUid => _auth.currentUser!.uid;

  /// Public getter for current user UID
  String get myUid => _myUid;

  /// Create a new group
  Future<String> createGroup({
    required String name,
    String? description,
    String? photoUrl,
    required List<String> memberUids,
  }) async {
    final groupId = _uuid.v4();
    final allMembers = [_myUid, ...memberUids];

    final group = GroupModel(
      id: groupId,
      name: name,
      description: description,
      photoUrl: photoUrl,
      createdBy: _myUid,
      members: allMembers,
      memberIds: allMembers,
      admins: [_myUid],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('groups').doc(groupId).set(group.toMap());
    return groupId;
  }

  /// Send a message to the group (supports replyTo for Phase 1)
  Future<void> sendGroupMessage({
    required String groupId,
    required String text,
    String type = 'text',
    String? mediaUrl,
    String? fileName,
    ReplyData? replyTo,
    bool isForwarded = false,
  }) async {
    final messageId = _uuid.v4();
    final message = MessageModel(
      id: messageId,
      senderId: _myUid,
      text: text,
      type: type,
      mediaUrl: mediaUrl,
      fileName: fileName,
      replyTo: replyTo,
      isForwarded: isForwarded,
      seenBy: [_myUid],
      createdAt: DateTime.now(),
    );

    final groupRef = _firestore.collection('groups').doc(groupId);
    final messageRef = groupRef.collection('messages').doc(messageId);

    final batch = _firestore.batch();

    batch.set(messageRef, message.toMap());

    batch.update(groupRef, {
      'lastMessage': {
        'text': type == 'text' ? text : '[$type]',
        'senderId': _myUid,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'type': type,
      },
    });

    await batch.commit();

    // Send push notification to all group members via OneSignal
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final memberIds = List<String>.from(
          groupDoc.data()?['memberIds'] ?? groupDoc.data()?['members'] ?? []);
      final recipients = memberIds.where((id) => id != _myUid).toList();

      final myDoc = await _firestore.collection('users').doc(_myUid).get();
      final myName = myDoc.data()?['name'] as String? ?? 'Someone';
      final groupName = groupDoc.data()?['name'] as String? ?? 'Group';

      final playerIds = <String>[];
      for (final uid in recipients) {
        final doc = await _firestore.collection('users').doc(uid).get();
        final pid = doc.data()?['oneSignalPlayerId'] as String?;
        if (pid != null && pid.isNotEmpty) playerIds.add(pid);
      }

      if (playerIds.isNotEmpty) {
        final notifText = type == 'text' ? text : '📎 Attachment';
        await NotificationService.sendGroupMessageNotification(
          recipientPlayerIds: playerIds,
          senderName: myName,
          groupName: groupName,
          messageText: notifText,
          groupId: groupId,
        );
      }
    } catch (_) {}
  }

  /// Add members to a group
  Future<void> addMembers(String groupId, List<String> uids) async {
    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion(uids),
      'memberIds': FieldValue.arrayUnion(uids),
    });
  }

  /// Remove a member from the group (admin only)
  Future<void> removeMember(String groupId, String uid) async {
    final batch = _firestore.batch();
    final groupRef = _firestore.collection('groups').doc(groupId);

    batch.update(groupRef, {
      'members': FieldValue.arrayRemove([uid]),
      'memberIds': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
    });

    await batch.commit();
  }

  /// Make a member an admin
  Future<void> makeAdmin(String groupId, String uid) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayUnion([uid]),
    });
  }

  /// Remove admin privileges
  Future<void> removeAdmin(String groupId, String uid) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayRemove([uid]),
    });
  }

  /// Leave a group
  Future<void> leaveGroup(String groupId) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final data = groupDoc.data()!;
    final members = List<String>.from(data['members'] ?? []);
    final admins = List<String>.from(data['admins'] ?? []);
    final isAdmin = admins.contains(_myUid);

    // If admin and more than one member, auto-promote first non-admin
    if (isAdmin && members.length > 1) {
      final firstNonAdmin = members.firstWhere(
        (id) => id != _myUid && !admins.contains(id),
        orElse: () => '',
      );
      if (firstNonAdmin.isNotEmpty) {
        await _firestore.collection('groups').doc(groupId).update({
          'admins': FieldValue.arrayUnion([firstNonAdmin]),
        });
      }
    }

    // If last member, delete the group
    if (members.length <= 1) {
      await _firestore.collection('groups').doc(groupId).delete();
      return;
    }

    final batch = _firestore.batch();
    final groupRef = _firestore.collection('groups').doc(groupId);

    batch.update(groupRef, {
      'members': FieldValue.arrayRemove([_myUid]),
      'memberIds': FieldValue.arrayRemove([_myUid]),
      'admins': FieldValue.arrayRemove([_myUid]),
    });

    await batch.commit();
  }

  /// Update group info (name, description, photo)
  Future<void> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (photoUrl != null) updates['photoUrl'] = photoUrl;

    if (updates.isNotEmpty) {
      await _firestore.collection('groups').doc(groupId).update(updates);
    }
  }

  /// Delete a group — client-side batch delete (no Cloud Functions needed)
  Future<void> deleteGroup(String groupId) async {
    final groupRef = _firestore.collection('groups').doc(groupId);

    // Step 1: Delete all messages in batches of 500
    QuerySnapshot messages =
        await groupRef.collection('messages').limit(500).get();

    while (messages.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Get next batch
      messages =
          await groupRef.collection('messages').limit(500).get();
    }

    // Step 2: Delete the group document itself
    await groupRef.delete();
  }

  /// Toggle canEditInfo permission for a member
  Future<void> toggleCanEditInfo(String groupId, String uid) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return;
    final perms = Map<String, dynamic>.from(doc.data()!['memberPermissions'] ?? {});
    final userPerms = Map<String, dynamic>.from(perms[uid] ?? {});
    userPerms['canEditInfo'] = !(userPerms['canEditInfo'] ?? false);
    perms[uid] = userPerms;
    await _firestore.collection('groups').doc(groupId).update({
      'memberPermissions': perms,
    });
  }

  /// Toggle canAddMembers permission for a member
  Future<void> toggleCanAddMembers(String groupId, String uid) async {
    final doc = await _firestore.collection('groups').doc(groupId).get();
    if (!doc.exists) return;
    final perms = Map<String, dynamic>.from(doc.data()!['memberPermissions'] ?? {});
    final userPerms = Map<String, dynamic>.from(perms[uid] ?? {});
    userPerms['canAddMembers'] = !(userPerms['canAddMembers'] ?? false);
    perms[uid] = userPerms;
    await _firestore.collection('groups').doc(groupId).update({
      'memberPermissions': perms,
    });
  }
}
