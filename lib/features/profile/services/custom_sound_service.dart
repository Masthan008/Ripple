import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/env.dart';

final customSoundServiceProvider = Provider<CustomSoundService>((ref) {
  return CustomSoundService();
});

class CustomSoundService {
  final FirebaseFirestore _firestore = FirebaseService.firestore;
  final String _bucketName = Env.supabaseBucketName;

  static const List<String> prebuiltSounds = [
    'Aqua Chime',
    'Liquid Drip',
    'Bubbles',
    'Ocean Wave',
    'Submarine',
    'Ripple Ping',
    'Deep Abyss',
    'Neon Splash',
    'Sonar Pulse',
    'Marine Echo',
  ];

  static String getSoundAssetPath(String soundName) {
    switch (soundName) {
      case 'Aqua Chime':
        return 'assets/sounds/aqua_chime.mp3';
      case 'Liquid Drip':
        return 'assets/sounds/liquid_drip.mp3';
      case 'Bubbles':
        return 'assets/sounds/bubbles.mp3';
      case 'Ocean Wave':
        return 'assets/sounds/ocean_wave.mp3';
      case 'Submarine':
        return 'assets/sounds/submarine.mp3';
      case 'Ripple Ping':
        return 'assets/sounds/ripple_ping.mp3';
      case 'Deep Abyss':
        return 'assets/sounds/deep_abyss.mp3';
      case 'Neon Splash':
        return 'assets/sounds/neon_splash.mp3';
      case 'Sonar Pulse':
        return 'assets/sounds/sonar_pulse.mp3';
      case 'Marine Echo':
        return 'assets/sounds/marine_echo.mp3';
      default:
        return 'assets/sounds/ripple_ping.mp3';
    }
  }

  /// Upload custom notification audio to Supabase Storage
  Future<String?> uploadCustomSound(File file, String fileName) async {
    try {
      if (_bucketName.isEmpty) {
        debugPrint('❌ SUPABASE_BUCKET_NAME not set in .env');
        return null;
      }
      final bucket = SupabaseService.client.storage.from(_bucketName);
      final cleanFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final path = 'notification_sounds/$cleanFileName';

      debugPrint('📤 Uploading custom sound to Supabase: $path');
      await bucket.upload(
        path,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      return bucket.getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ Custom sound upload failed: $e');
      return null;
    }
  }

  /// Save global default sound settings for a category
  Future<void> saveGlobalSoundSetting({
    required String uid,
    required String category, // 'messages', 'groups', 'calls', 'statuses'
    required String soundName,
    String? soundUrl,
  }) async {
    final docRef = _firestore.collection('users').doc(uid);
    await docRef.set({
      'notificationSounds': {
        category: {
          'name': soundName,
          'url': soundUrl,
        }
      }
    }, SetOptions(merge: true));
  }

  /// Save individual override sound settings for a specific chat or group
  Future<void> saveChatSoundOverride({
    required String uid,
    required String chatId,
    required bool enabled,
    required String soundName,
    String? soundUrl,
  }) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('custom_notifications')
        .doc(chatId);
        
    await docRef.set({
      'chatId': chatId,
      'enabled': enabled,
      'soundName': soundName,
      'soundUrl': soundUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Load custom notification sound setting for a specific chat
  Future<Map<String, dynamic>?> loadChatSoundOverride(String uid, String chatId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('custom_notifications')
          .doc(chatId)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }
}
