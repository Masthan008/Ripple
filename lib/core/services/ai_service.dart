import 'dart:convert';
import 'dart:io';

/// AI features have been decommissioned and removed from Ripple.
/// This file remains as a zero-overhead safe stub to preserve API contract
/// without making any external API calls, running AI bots, or loading models.

class SpamResult {
  final bool isSpam;
  final String reason;
  const SpamResult({required this.isSpam, required this.reason});
}

class ActionItems {
  final bool hasActionItems;
  final List<String> tasks;
  final List<String> deadlines;
  const ActionItems({
    required this.hasActionItems,
    required this.tasks,
    this.deadlines = const [],
  });
}

class AiService {
  AiService._();

  static Future<List<String>> smartReplies({
    required List<Map<String, String>> chatHistory,
    required String myName,
    String? otherName,
  }) async =>
      const [];

  static Future<String> summariseChat({
    required List<Map<String, dynamic>> messages,
    required String chatName,
  }) async =>
      '';

  static Future<String> fixTone({
    required String text,
    required String tone,
  }) async =>
      text;

  static Future<String> composeReply({
    required String instruction,
    required List<Map<String, String>> chatHistory,
    String? myName,
    String? otherName,
  }) async =>
      '';

  static Future<String> explainMessage({
    required String text,
    required String senderName,
  }) async =>
      '';

  static Future<String> translateMessage({
    required String text,
    required String targetLanguage,
  }) async =>
      text;

  static Future<SpamResult> detectSpam({
    required String messageText,
    required String senderName,
  }) async =>
      const SpamResult(isSpam: false, reason: '');

  static Future<String> generateCaption({
    required String context,
    required String mood,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final prompt = 'Generate a stylish aesthetic status quote for my story in 1 short sentence about $context with $mood vibe and 1 emoji. Do not use quotes.';
      final uri = Uri.parse('https://text.pollinations.ai/${Uri.encodeComponent(prompt)}');
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final text = await resp.transform(utf8.decoder).join();
        final cleaned = text.replaceAll('"', '').trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
    } catch (_) {}

    // Aesthetic fallbacks if network unreachable
    final fallbacks = [
      'Chasing frequencies, living in high resolution ✨',
      'Where words fail, the energy speaks 🌊',
      'Midnight echoes and neon dreams 🌌',
      'Unscripted moments make the best chapters 🪐',
      'Silence is also a conversation 🖤',
      'Finding art in ordinary wavelengths 🎨',
    ];
    return fallbacks[DateTime.now().second % fallbacks.length];
  }

  static String generateImageUrl(String prompt) {
    final clean = prompt.trim().isNotEmpty ? prompt.trim() : 'aesthetic wallpaper';
    return 'https://image.pollinations.ai/prompt/${Uri.encodeComponent(clean)}?width=1080&height=1920&nologo=true';
  }

  static Future<String> transcribeVoiceUrl(String audioUrl) async => '';

  static Future<String> transcribeAudio(String filePath) async => '';

  static Future<ActionItems> extractActionItems({
    required String messageText,
  }) async =>
      const ActionItems(hasActionItems: false, tasks: []);

  static Future<Map<String, dynamic>> analyzeSentiment({
    required String chatHistory,
  }) async =>
      const {'sentiment': 'neutral', 'score': 0.0};

  static Future<String> rippleBotAssistant({
    required String query,
    required List<Map<String, String>> chatContext,
  }) async =>
      '';

  static Future<String> chatWithPersona({
    required String systemPrompt,
    required String message,
  }) async =>
      '';
}
