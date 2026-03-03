import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed wrapper around flutter_dotenv for safe env variable access
class Env {
  Env._();

  /// Call this before runApp()
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  // ─── Firebase ────────────────────────────────────────
  static String get firebaseApiKey => dotenv.env['FIREBASE_API_KEY'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  static String get firebaseMessagingSenderId =>
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseAuthDomain =>
      dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';
  static String get firebaseStorageBucket =>
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  static String get firebaseDatabaseUrl =>
      dotenv.env['FIREBASE_DATABASE_URL'] ?? '';

  // ─── Agora (Video & Audio Calls) ────────────────────
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  // ─── Supabase ────────────────────────────────────────
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseServiceRoleKey =>
      dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
  static String get supabaseBucketName =>
      dotenv.env['SUPABASE_BUCKET_NAME'] ?? 'ripple-files';

  // ─── Cloudinary ──────────────────────────────────────
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';
  static String get cloudinaryApiKey =>
      dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get cloudinaryApiSecret =>
      dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  static String get cloudinaryBaseUrl =>
      dotenv.env['CLOUDINARY_BASE_URL'] ?? '';

  // ─── ImageKit ────────────────────────────────────────
  static String get imagekitPublicKey =>
      dotenv.env['IMAGEKIT_PUBLIC_KEY'] ?? '';
  static String get imagekitPrivateKey =>
      dotenv.env['IMAGEKIT_PRIVATE_KEY'] ?? '';
  static String get imagekitUrlEndpoint =>
      dotenv.env['IMAGEKIT_URL_ENDPOINT'] ?? '';

  // ─── OneSignal ────────────────────────────────────────
  static String get oneSignalAppId =>
      dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  static String get oneSignalRestApiKey =>
      dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  // ─── App Config ──────────────────────────────────────
  static String get appName => dotenv.env['APP_NAME'] ?? 'Ripple';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  static bool get isDevelopment => appEnv == 'development';
}
