import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
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
          .map((doc) {
        if (!doc.exists) return null;
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
  Future<UserCredential?> signInWithGoogle() async {
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
      await _createUserDocIfNeeded(userCredential.user!);
      await _saveFcmToken(userCredential.user!.uid);
      return userCredential;
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
      await _saveFcmToken(userCredential.user!.uid);
      await _setOnlineStatus(userCredential.user!.uid, true);
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email, password, and name
  Future<UserCredential> signUpWithEmail({
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
      await _createUserDoc(userCredential.user!, name: name);
      await _saveFcmToken(userCredential.user!.uid);
      return userCredential;
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
      await _setOnlineStatus(uid, false);
      await _clearFcmToken(uid);
    }
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// Create user document in Firestore if it doesn't exist
  Future<void> _createUserDocIfNeeded(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _createUserDoc(user);
    } else {
      await _setOnlineStatus(user.uid, true);
    }
  }

  /// Create user document
  Future<void> _createUserDoc(User user, {String? name}) async {
    final userModel = UserModel(
      uid: user.uid,
      name: name ?? user.displayName ?? 'User',
      email: user.email ?? '',
      photoUrl: user.photoURL ?? '',
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(userModel.toMap());
  }

  /// Save FCM token to user document
  Future<void> _saveFcmToken(String uid) async {
    try {
      final token = await NotificationService.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    } catch (_) {}
  }

  /// Clear FCM token on logout
  Future<void> _clearFcmToken(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': '',
      });
    } catch (_) {}
  }

  /// Set online/offline status
  Future<void> _setOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
