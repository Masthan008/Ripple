import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing per-chat theme/wallpaper customization.
/// Stores preferences under the user's private subcollection `users/{uid}/chat_themes/{chatId}`.
class ChatThemeService {
  ChatThemeService._();

  /// Preset gradient themes
  static const List<Map<String, dynamic>> presets = [
    {'name': 'Default', 'colors': ['060D1A', '060D1A'], 'accent': '0EA5E9'},
    {'name': 'Ocean', 'colors': ['0C4A6E', '0A1628'], 'accent': '22D3EE'},
    {'name': 'Aurora', 'colors': ['1E1B4B', '0F172A'], 'accent': '818CF8'},
    {'name': 'Sunset', 'colors': ['7C2D12', '1C1917'], 'accent': 'FB923C'},
    {'name': 'Forest', 'colors': ['14532D', '0A1628'], 'accent': '4ADE80'},
    {'name': 'Berry', 'colors': ['831843', '1C1917'], 'accent': 'F472B6'},
    {'name': 'Volcano', 'colors': ['7F1D1D', '1C1917'], 'accent': 'F87171'},
    {'name': 'Nebula', 'colors': ['4C1D95', '0F172A'], 'accent': 'C084FC'},
  ];

  /// Preset solid colors (WhatsApp-style muted background hues)
  static const List<Map<String, dynamic>> solidColors = [
    {'name': 'Teal Sage', 'color': '1E2D2F', 'accent': '22D3EE'},
    {'name': 'Muted Lavender', 'color': '2E253A', 'accent': 'C084FC'},
    {'name': 'Warm Amber', 'color': '3D2C20', 'accent': 'FB923C'},
    {'name': 'Slate Grey', 'color': '1F2937', 'accent': '9CA3AF'},
    {'name': 'Rose Dust', 'color': '3A1C28', 'accent': 'F472B6'},
    {'name': 'Dark Forest', 'color': '102A1E', 'accent': '4ADE80'},
    {'name': 'Deep Navy', 'color': '0B132B', 'accent': '60A5FA'},
    {'name': 'Charcoal', 'color': '18181B', 'accent': 'E4E4E7'},
  ];

  /// Get the theme for a chat (specific to the logged-in user).
  static Future<Map<String, dynamic>?> getTheme(String chatId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_themes')
          .doc(chatId)
          .get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  /// Get a real-time stream of the theme for a chat (specific to the logged-in user).
  static Stream<DocumentSnapshot<Map<String, dynamic>>> getThemeStream(String chatId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chat_themes')
        .doc(chatId)
        .snapshots();
  }

  /// Set a theme for a chat (specific to the logged-in user)
  static Future<void> setTheme({
    required String chatId,
    required List<String> gradientColors,
    required String accentColor,
    String? solidColor,
    String? imageUrl,
    String? themePresetName,
    double? dimValue,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chat_themes')
        .doc(chatId)
        .set({
      'gradientColors': gradientColors,
      'accentColor': accentColor,
      'solidColor': solidColor,
      'imageUrl': imageUrl,
      'themePresetName': themePresetName,
      'dimValue': dimValue ?? 0.45,
      'setAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove custom theme (revert to default)
  static Future<void> clearTheme(String chatId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chat_themes')
        .doc(chatId)
        .delete();
  }
}
