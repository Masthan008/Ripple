import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing per-chat theme customization.
/// Stores theme preferences (gradient colors, accent color) in Firestore.
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

  /// Get the theme for a chat. Returns null if no custom theme is set.
  static Future<Map<String, dynamic>?> getTheme(String chatId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .get();
      return doc.data()?['theme'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Set a theme for a chat
  static Future<void> setTheme({
    required String chatId,
    required List<String> gradientColors,
    required String accentColor,
  }) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'theme': {
        'gradientColors': gradientColors,
        'accentColor': accentColor,
        'setBy': FirebaseAuth.instance.currentUser?.uid,
        'setAt': FieldValue.serverTimestamp(),
      },
    });
  }

  /// Remove custom theme (revert to default)
  static Future<void> clearTheme(String chatId) async {
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'theme': FieldValue.delete(),
    });
  }
}
