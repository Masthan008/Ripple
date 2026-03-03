import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_service.dart';
import '../../auth/models/user_model.dart';

// ─── All Users Provider (excluding self & blocked) ───────
/// Stream of all users for discovery — excludes current user and blocked
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.usersCollection.snapshots().map((snapshot) {
    return snapshot.docs
        .where((doc) => doc.id != currentUser.uid)
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
  });
});

// ─── Friend Requests Received Provider ───────────────────
final friendRequestsReceivedProvider =
    StreamProvider<List<UserModel>>((ref) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.usersCollection
      .doc(currentUser.uid)
      .snapshots()
      .asyncMap((doc) async {
    if (!doc.exists) return <UserModel>[];
    final data = doc.data()!;
    final received =
        List<String>.from(data['friendRequests']?['received'] ?? []);
    if (received.isEmpty) return <UserModel>[];

    // Fetch user details for each request
    final futures = received.map((uid) =>
        FirebaseService.usersCollection.doc(uid).get());
    final docs = await Future.wait(futures);
    return docs
        .where((d) => d.exists)
        .map((d) => UserModel.fromFirestore(d))
        .toList();
  });
});

// ─── Friend Requests Sent Provider ───────────────────────
final friendRequestsSentProvider = StreamProvider<List<String>>((ref) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.usersCollection
      .doc(currentUser.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return <String>[];
    final data = doc.data()!;
    return List<String>.from(data['friendRequests']?['sent'] ?? []);
  });
});

// ─── Friends List Provider ───────────────────────────────
final friendsListProvider = StreamProvider<List<UserModel>>((ref) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.usersCollection
      .doc(currentUser.uid)
      .snapshots()
      .asyncMap((doc) async {
    if (!doc.exists) return <UserModel>[];
    final data = doc.data()!;
    final friendUids = List<String>.from(data['friends'] ?? []);
    if (friendUids.isEmpty) return <UserModel>[];

    final futures = friendUids.map((uid) =>
        FirebaseService.usersCollection.doc(uid).get());
    final docs = await Future.wait(futures);
    return docs
        .where((d) => d.exists)
        .map((d) => UserModel.fromFirestore(d))
        .toList();
  });
});

// ─── Blocked Users Provider ──────────────────────────────
final blockedUsersProvider = StreamProvider<List<String>>((ref) {
  final currentUser = FirebaseService.auth.currentUser;
  if (currentUser == null) return Stream.value([]);

  return FirebaseService.usersCollection
      .doc(currentUser.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return <String>[];
    final data = doc.data()!;
    return List<String>.from(data['blockedUsers'] ?? []);
  });
});

// ─── Friends Service ─────────────────────────────────────
final friendsServiceProvider =
    Provider<FriendsService>((ref) => FriendsService());

class FriendsService {
  final _firestore = FirebaseService.firestore;
  final _auth = FirebaseService.auth;

  String get _myUid => _auth.currentUser!.uid;

  /// Send a friend request to another user
  Future<void> sendFriendRequest(String targetUid) async {
    final batch = _firestore.batch();

    // Add to my sent requests
    batch.update(_firestore.collection('users').doc(_myUid), {
      'friendRequests.sent': FieldValue.arrayUnion([targetUid]),
    });

    // Add to their received requests
    batch.update(_firestore.collection('users').doc(targetUid), {
      'friendRequests.received': FieldValue.arrayUnion([_myUid]),
    });

    await batch.commit();
  }

  /// Accept a friend request
  Future<void> acceptFriendRequest(String fromUid) async {
    final batch = _firestore.batch();
    final myRef = _firestore.collection('users').doc(_myUid);
    final theirRef = _firestore.collection('users').doc(fromUid);

    // Add each other as friends
    batch.update(myRef, {
      'friends': FieldValue.arrayUnion([fromUid]),
      'friendRequests.received': FieldValue.arrayRemove([fromUid]),
    });
    batch.update(theirRef, {
      'friends': FieldValue.arrayUnion([_myUid]),
      'friendRequests.sent': FieldValue.arrayRemove([_myUid]),
    });

    await batch.commit();
  }

  /// Reject / decline a friend request
  Future<void> rejectFriendRequest(String fromUid) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(_myUid), {
      'friendRequests.received': FieldValue.arrayRemove([fromUid]),
    });
    batch.update(_firestore.collection('users').doc(fromUid), {
      'friendRequests.sent': FieldValue.arrayRemove([_myUid]),
    });

    await batch.commit();
  }

  /// Cancel a sent friend request
  Future<void> cancelFriendRequest(String targetUid) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(_myUid), {
      'friendRequests.sent': FieldValue.arrayRemove([targetUid]),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'friendRequests.received': FieldValue.arrayRemove([_myUid]),
    });

    await batch.commit();
  }

  /// Remove a friend (unfriend)
  Future<void> unfriend(String friendUid) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('users').doc(_myUid), {
      'friends': FieldValue.arrayRemove([friendUid]),
    });
    batch.update(_firestore.collection('users').doc(friendUid), {
      'friends': FieldValue.arrayRemove([_myUid]),
    });

    await batch.commit();
  }

  /// Block a user (bidirectional update)
  Future<void> blockUser(String targetUid) async {
    final batch = _firestore.batch();

    // Add to my blocked list
    batch.update(_firestore.collection('users').doc(_myUid), {
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
      'friends': FieldValue.arrayRemove([targetUid]),
    });

    // Remove me from their friends
    batch.update(_firestore.collection('users').doc(targetUid), {
      'friends': FieldValue.arrayRemove([_myUid]),
    });

    await batch.commit();
  }

  /// Unblock a user
  Future<void> unblockUser(String targetUid) async {
    await _firestore.collection('users').doc(_myUid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    });
  }
}
