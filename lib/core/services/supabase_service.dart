import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/env.dart';

/// Supabase service for file/document storage
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Use service role key — the anon key must be a JWT.
      // Service role key bypasses RLS and allows file uploads.
      anonKey: Env.supabaseServiceRoleKey.isNotEmpty
          ? Env.supabaseServiceRoleKey
          : Env.supabaseAnonKey,
    );
  }

  /// Upload a file (PDF, document) to Supabase Storage
  /// Returns the public URL
  static Future<String?> uploadFile(File file, String fileName) async {
    try {
      final bucketName = Env.supabaseBucketName;
      if (bucketName.isEmpty) {
        debugPrint('❌ SUPABASE_BUCKET_NAME not set in .env');
        return null;
      }

      final bucket = client.storage.from(bucketName);
      final path = 'documents/$fileName';

      debugPrint('📤 Uploading file to Supabase: $path');

      await bucket.upload(
        path,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,  // overwrite if exists
        ),
      );

      final publicUrl = bucket.getPublicUrl(path);
      debugPrint('✅ File uploaded: $publicUrl');
      return publicUrl;
    } on StorageException catch (e) {
      debugPrint('❌ Supabase Storage error: ${e.message} (${e.statusCode})');
      debugPrint('   Error details: ${e.error}');
      return null;
    } catch (e) {
      debugPrint('❌ Supabase upload error: $e');
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
      debugPrint('❌ Supabase getFileUrl error: $e');
      return null;
    }
  }

  /// Send real email 6-digit OTP code to user's email via Supabase Auth
  static Future<bool> sendEmailOtp(String email) async {
    try {
      await client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
      debugPrint('📧 Email OTP sent via Supabase to $email');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase sendEmailOtp error: $e');
      return false;
    }
  }

  /// Verify 6-digit email OTP token via Supabase Auth
  static Future<bool> verifyEmailOtp(String email, String token) async {
    try {
      final response = await client.auth.verifyOTP(
        type: OtpType.email,
        email: email.trim(),
        token: token.trim(),
      );
      debugPrint('✅ Supabase Email OTP verified for $email');
      return response.session != null || response.user != null;
    } catch (e) {
      debugPrint('❌ Supabase verifyEmailOtp error: $e');
      return false;
    }
  }
}
