import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed wrapper around flutter_dotenv and compile-time environment variables for secure access
class Env {
  Env._();

  /// Call this before runApp()
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Omission of .env asset is expected in production builds where credentials are obfuscated at compile-time
    }
  }

  // ─── Firebase ────────────────────────────────────────
  static String get firebaseApiKey => const String.fromEnvironment('FIREBASE_API_KEY') != ''
      ? const String.fromEnvironment('FIREBASE_API_KEY')
      : dotenv.env['FIREBASE_API_KEY'] ?? '';

  static String get firebaseAppId => const String.fromEnvironment('FIREBASE_APP_ID') != ''
      ? const String.fromEnvironment('FIREBASE_APP_ID')
      : dotenv.env['FIREBASE_APP_ID'] ?? '';

  static String get firebaseMessagingSenderId => const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID') != ''
      ? const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID')
      : dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';

  static String get firebaseProjectId => const String.fromEnvironment('FIREBASE_PROJECT_ID') != ''
      ? const String.fromEnvironment('FIREBASE_PROJECT_ID')
      : dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  static String get firebaseAuthDomain => const String.fromEnvironment('FIREBASE_AUTH_DOMAIN') != ''
      ? const String.fromEnvironment('FIREBASE_AUTH_DOMAIN')
      : dotenv.env['FIREBASE_AUTH_DOMAIN'] ?? '';

  static String get firebaseStorageBucket => const String.fromEnvironment('FIREBASE_STORAGE_BUCKET') != ''
      ? const String.fromEnvironment('FIREBASE_STORAGE_BUCKET')
      : dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';

  static String get firebaseDatabaseUrl => const String.fromEnvironment('FIREBASE_DATABASE_URL') != ''
      ? const String.fromEnvironment('FIREBASE_DATABASE_URL')
      : dotenv.env['FIREBASE_DATABASE_URL'] ?? '';

  // ─── Daily.co (Video & Audio Calls) ──────────────────
  static String get dailyApiKey => const String.fromEnvironment('DAILY_API_KEY') != ''
      ? const String.fromEnvironment('DAILY_API_KEY')
      : dotenv.env['DAILY_API_KEY'] ?? '';

  static String get dailyDomain => const String.fromEnvironment('DAILY_DOMAIN') != ''
      ? const String.fromEnvironment('DAILY_DOMAIN')
      : dotenv.env['DAILY_DOMAIN'] ?? '';

  // ─── Supabase ────────────────────────────────────────
  static String get supabaseUrl => const String.fromEnvironment('SUPABASE_URL') != ''
      ? const String.fromEnvironment('SUPABASE_URL')
      : dotenv.env['SUPABASE_URL'] ?? '';

  static String get supabaseAnonKey => const String.fromEnvironment('SUPABASE_ANON_KEY') != ''
      ? const String.fromEnvironment('SUPABASE_ANON_KEY')
      : dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static String get supabaseServiceRoleKey => const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY') != ''
      ? const String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY')
      : dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

  static String get supabaseBucketName => const String.fromEnvironment('SUPABASE_BUCKET_NAME') != ''
      ? const String.fromEnvironment('SUPABASE_BUCKET_NAME')
      : dotenv.env['SUPABASE_BUCKET_NAME'] ?? 'ripple-files';

  // ─── Cloudinary ──────────────────────────────────────
  static String get cloudinaryCloudName => const String.fromEnvironment('CLOUDINARY_CLOUD_NAME') != ''
      ? const String.fromEnvironment('CLOUDINARY_CLOUD_NAME')
      : dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  static String get cloudinaryUploadPreset => const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET') != ''
      ? const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET')
      : dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String get cloudinaryApiKey => const String.fromEnvironment('CLOUDINARY_API_KEY') != ''
      ? const String.fromEnvironment('CLOUDINARY_API_KEY')
      : dotenv.env['CLOUDINARY_API_KEY'] ?? '';

  static String get cloudinaryApiSecret => const String.fromEnvironment('CLOUDINARY_API_SECRET') != ''
      ? const String.fromEnvironment('CLOUDINARY_API_SECRET')
      : dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  static String get cloudinaryBaseUrl => const String.fromEnvironment('CLOUDINARY_BASE_URL') != ''
      ? const String.fromEnvironment('CLOUDINARY_BASE_URL')
      : dotenv.env['CLOUDINARY_BASE_URL'] ?? '';

  // ─── ImageKit ────────────────────────────────────────
  static String get imagekitPublicKey => const String.fromEnvironment('IMAGEKIT_PUBLIC_KEY') != ''
      ? const String.fromEnvironment('IMAGEKIT_PUBLIC_KEY')
      : dotenv.env['IMAGEKIT_PUBLIC_KEY'] ?? '';

  static String get imagekitPrivateKey => const String.fromEnvironment('IMAGEKIT_PRIVATE_KEY') != ''
      ? const String.fromEnvironment('IMAGEKIT_PRIVATE_KEY')
      : dotenv.env['IMAGEKIT_PRIVATE_KEY'] ?? '';

  static String get imagekitUrlEndpoint => const String.fromEnvironment('IMAGEKIT_URL_ENDPOINT') != ''
      ? const String.fromEnvironment('IMAGEKIT_URL_ENDPOINT')
      : dotenv.env['IMAGEKIT_URL_ENDPOINT'] ?? '';

  // ─── OneSignal ────────────────────────────────────────
  static String get oneSignalAppId => const String.fromEnvironment('ONESIGNAL_APP_ID') != ''
      ? const String.fromEnvironment('ONESIGNAL_APP_ID')
      : dotenv.env['ONESIGNAL_APP_ID'] ?? '';

  static String get oneSignalRestApiKey => const String.fromEnvironment('ONESIGNAL_REST_API_KEY') != ''
      ? const String.fromEnvironment('ONESIGNAL_REST_API_KEY')
      : dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  // ─── Giphy ────────────────────────────────────────────
  static String get giphyApiKey => const String.fromEnvironment('GIPHY_API_KEY') != ''
      ? const String.fromEnvironment('GIPHY_API_KEY')
      : dotenv.env['GIPHY_API_KEY'] ?? '';

  // ─── Groq AI ───────────────────────────
  static String get groqApiKey => const String.fromEnvironment('GROQ_API_KEY') != ''
      ? const String.fromEnvironment('GROQ_API_KEY')
      : dotenv.env['GROQ_API_KEY'] ?? '';

  // ─── App Config ──────────────────────────────────────
  static String get appName => const String.fromEnvironment('APP_NAME') != ''
      ? const String.fromEnvironment('APP_NAME')
      : dotenv.env['APP_NAME'] ?? 'Ripple';

  static String get appVersion => const String.fromEnvironment('APP_VERSION') != ''
      ? const String.fromEnvironment('APP_VERSION')
      : dotenv.env['APP_VERSION'] ?? '1.0.0';

  static String get appEnv => const String.fromEnvironment('APP_ENV') != ''
      ? const String.fromEnvironment('APP_ENV')
      : dotenv.env['APP_ENV'] ?? 'development';

  static bool get isDevelopment => appEnv == 'development';
}
