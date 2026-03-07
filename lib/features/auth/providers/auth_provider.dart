import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/presence_service.dart';
import '../models/user_model.dart';

// ─── Auth State Provider ─────────────────────────────────
/// Stream of Firebase auth state changes — uses .distinct() to prevent
/// rapid duplicate emissions during Google sign-in
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.auth
      .authStateChanges()
      .distinct((prev, next) => prev?.uid == next?.uid);
});

// ─── Current User Provider ───────────────────────────────
/// Stream of current user's Firestore document.
/// Returns null if:
///   - No Firebase auth
///   - No Firestore doc
///   - isRegistrationComplete != true
///
/// This is the SINGLE SOURCE OF TRUTH for whether a user
/// has completed registration. GoRouter redirect checks this.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return FirebaseService.usersCollection
          .doc(user.uid)
          .snapshots()
          .map((doc) {
        if (!doc.exists) return null;
        final data = doc.data();

        // Check isRegistrationComplete flag — this is the ONLY check
        // Old users who don't have this field yet are treated as complete
        // (they were registered before this field was introduced)
        final hasRegFlag = data?.containsKey('isRegistrationComplete') ?? false;
        if (hasRegFlag) {
          final isComplete = data!['isRegistrationComplete'] as bool? ?? false;
          if (!isComplete) return null; // Registration not finished
        } else {
          // Legacy user — no isRegistrationComplete field.
          // Check if they have a name (all old registered users do)
          final name = data?['name'] as String? ?? '';
          if (name.isEmpty) return null;
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
  /// Returns (credential, isNewUser) — isNewUser=true means registration not complete
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

      // Check if user doc already exists with completed registration
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final hasRegFlag = data?.containsKey('isRegistrationComplete') ?? false;

        if (hasRegFlag) {
          final isComplete = data!['isRegistrationComplete'] as bool? ?? false;
          if (isComplete) {
            // Fully registered user — set online + save FCM
            await _setOnlineStatus(uid, true);
            await _saveFcmToken(uid);
            return (credential: userCredential, isNewUser: false);
          }
          // Has flag but it's false — registration was started but not completed
          return (credential: userCredential, isNewUser: true);
        } else {
          // Legacy user (no isRegistrationComplete field) — check name
          final name = data?['name'] as String? ?? '';
          if (name.isNotEmpty) {
            await _setOnlineStatus(uid, true);
            await _saveFcmToken(uid);
            return (credential: userCredential, isNewUser: false);
          }
        }
      }

      // New Google user — create skeleton doc with isRegistrationComplete: false
      // so the currentUserProvider stream returns null (registration incomplete)
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': '',
        'email': userCredential.user!.email ?? '',
        'photoUrl': userCredential.user!.photoURL ?? '',
        'bio': '',
        'username': '',
        'isRegistrationComplete': false,
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

      return (credential: userCredential, isNewUser: true);
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
      await _ensureUserDocument(userCredential.user!);

      await _saveFcmToken(uid);
      await _setOnlineStatus(uid, true);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email, password, and name — returns (credential, isNewUser)
  /// Creates user doc with isRegistrationComplete: false
  /// RegisterScreen will set it to true after user fills username/bio
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

      // Create incomplete doc — RegisterScreen will complete it
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
  /// isRegistrationComplete starts as FALSE — set to true only in RegisterScreen.
  /// Uses .set(merge: true) so it never overwrites existing data.
  Future<void> createUserDocument(User user, {String? name}) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name ?? user.displayName ?? '',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'bio': '',
        'username': '',
        'isRegistrationComplete': false,
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
  /// If doc is missing, creates it. If doc exists, just updates online status.
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
