import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/env.dart';

/// Supabase service for file/document storage
/// Full implementation in Phase 5
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  /// Upload a file (PDF, document) to Supabase Storage
  /// Returns the public URL
  static Future<String?> uploadFile(File file, String fileName) async {
    try {
      final bucket = client.storage.from(Env.supabaseBucketName);
      final path = 'documents/$fileName';

      await bucket.upload(path, file);

      final publicUrl = bucket.getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      return null;
    }
  }

  /// Download a file URL
  static String? getFileUrl(String path) {
    try {
      return client.storage
          .from(Env.supabaseBucketName)
          .getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}
