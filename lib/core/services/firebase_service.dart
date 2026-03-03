import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/env.dart';

/// Firebase service — initialization and instance getters
class FirebaseService {
  FirebaseService._();

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Initialize Firebase with env vars
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: Env.firebaseApiKey,
          appId: Env.firebaseAppId,
          messagingSenderId: Env.firebaseMessagingSenderId,
          projectId: Env.firebaseProjectId,
          authDomain: Env.firebaseAuthDomain,
          storageBucket: Env.firebaseStorageBucket,
          databaseURL: Env.firebaseDatabaseUrl,
        ),
      );
    } on FirebaseException catch (e) {
      // If already initialized by native plugin, just continue
      if (e.code != 'duplicate-app') rethrow;
    }
  }

  // ─── Firestore Collection References ─────────────────
  static CollectionReference<Map<String, dynamic>> get usersCollection =>
      firestore.collection('users');

  static CollectionReference<Map<String, dynamic>> get chatsCollection =>
      firestore.collection('chats');

  static CollectionReference<Map<String, dynamic>> get groupsCollection =>
      firestore.collection('groups');

  static CollectionReference<Map<String, dynamic>> get callsCollection =>
      firestore.collection('calls');
}
