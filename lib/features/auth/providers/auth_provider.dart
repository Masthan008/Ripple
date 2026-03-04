import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/presence_service.dart';
import '../models/user_model.dart';

// ─── Auth State Provider ─────────────────────────────────
/// Stream of Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth.authStateChanges();
});

// ─── Current User Provider ───────────────────────────────
/// Stream of current user's Firestore document
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseService.usersCollection
          .doc(user.uid)
          .snapshots()
          .asyncMap((doc) async {
        if (!doc.exists) {
          // Safety net: auto-create user document if auth user exists
          // but Firestore doc is missing
          await AuthService().createUserDocument(user);
          // Return a temporary model while the stream refreshes
          return UserModel(
            uid: user.uid,
            name: user.displayName ?? user.email?.split('@')[0] ?? 'User',
            email: user.email ?? '',
            photoUrl: user.photoURL ?? '',
          );
        }
        return UserModel.fromFirestore(doc);
      });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// ─── Auth Service Provider ───────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Auth service handling Google Sign-In, Email/Password, and user doc management
class AuthService {
  final FirebaseAuth _auth = FirebaseService.auth;
  final FirebaseFirestore _firestore = FirebaseService.firestore;

  /// Sign in with Google
  /// Returns (credential, isNewUser) — isNewUser=true means no Firestore doc exists yet
  Future<({UserCredential credential, bool isNewUser})?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // Check if user doc already exists
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        // Existing user — set online + save FCM
        await _setOnlineStatus(uid, true);
        await _saveFcmToken(uid);
        return (credential: userCredential, isNewUser: false);
      } else {
        // Brand new Google user — create basic doc so they appear in Discover
        // RegisterScreen will update with username/bio
        await createUserDocument(userCredential.user!);
        return (credential: userCredential, isNewUser: true);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = userCredential.user!.uid;

      // Safety net: ensure user document exists
      // (handles edge case where doc was deleted or never created)
      await _ensureUserDocument(userCredential.user!);

      await _saveFcmToken(uid);
      await _setOnlineStatus(uid, true);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email, password, and name — returns (credential, isNewUser)
  /// Creates user doc IMMEDIATELY so all screens have data
  Future<({UserCredential credential, bool isNewUser})> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await userCredential.user!.updateDisplayName(name);

      // Create user document IMMEDIATELY — do not defer to RegisterScreen
      // RegisterScreen will update with username/bio via .set(merge: true)
      await createUserDocument(userCredential.user!, name: name);

      return (credential: userCredential, isNewUser: true);
    } catch (e) {
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await PresenceService.setOffline(uid);
      await _setOnlineStatus(uid, false);
      await _clearFcmToken(uid);
    }
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// Create user document in Firestore with all required fields.
  /// Uses .set(merge: true) so it never overwrites existing data.
  Future<void> createUserDocument(User user, {String? name}) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'User',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'bio': '',
        'username': '',
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'fcmToken': '',
        'oneSignalPlayerId': '',
        'isTypingTo': '',
        'friends': [],
        'blockedUsers': [],
        'blockedWereFriends': [],
        'friendRequests': {'sent': [], 'received': []},
        'notificationSettings': {
          'messages': true,
          'groupMessages': true,
          'friendRequests': true,
          'calls': true,
          'sounds': true,
          'vibration': true,
        },
        'privacySettings': {
          'showOnlineStatus': true,
          'showLastSeen': true,
          'readReceipts': true,
          'allowFriendRequests': true,
        },
        'twoFactorEnabled': false,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Safety net: ensure user document exists in Firestore.
  /// If doc is missing (e.g. deleted, signup handler failed), creates it.
  /// If doc exists, just updates online status.
  Future<void> _ensureUserDocument(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await createUserDocument(user);
      } else {
        await _setOnlineStatus(user.uid, true);
      }
    } catch (_) {}
  }

  /// Save push token — OneSignal handles this via syncPlayerId in HomeScreen
  Future<void> _saveFcmToken(String uid) async {
    // No-op: OneSignal manages player ID sync automatically
  }

  /// Clear push token on logout
  Future<void> _clearFcmToken(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'oneSignalPlayerId': '',
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Set online/offline status
  Future<void> _setOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
