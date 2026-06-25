import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/models/message_model.dart';
import '../models/ai_bot_model.dart';
import '../../../core/services/ai_service.dart';

final aiBotServiceProvider = Provider<AiBotService>((ref) => AiBotService());

class AiBotService {
  final List<AiBotModel> _defaultBots = [
    AiBotModel.create(
      name: 'Tech Helper',
      icon: Icons.code_rounded,
      description: 'Your go-to expert for fixing code, answering tech queries, and explaining complex logic.',
      systemPrompt: 'You are Tech Helper, a highly advanced engineering intelligence within the RIPPLE ecosystem. Your mission is to provide clean, optimized, and secure code solutions and explain complex computer science concepts. Format all code beautifully, use modern structures, and maintain a polite, clear, and helpful engineering tone.',
      colorHex: '0xFF10B981', // Emerald
    ),
    AiBotModel.create(
      name: 'Chill Friend',
      icon: Icons.sentiment_very_satisfied_rounded,
      description: 'Here to chat, vibe, and keep things relaxed. No stress allowed.',
      systemPrompt: 'You are Chill Friend, a relaxed and supportive AI buddy in RIPPLE. Your goal is to keep conversations warm, encouraging, and stress-free. Chat in a casual, modern, friendly manner, keep responses naturally short and positive, and offer chill vibes and thoughtful, empathetic responses.',
      colorHex: '0xFF8B5CF6', // Purple
    ),
    AiBotModel.create(
      name: 'Story Teller',
      icon: Icons.auto_stories_rounded,
      description: 'A creative companion that loves weaving tales, brainstorming ideas, and roleplaying.',
      systemPrompt: 'You are Story Teller, an imaginative and creative writer in RIPPLE. You specialize in spinning rich, engaging narrative journeys, brainstorming game rules or story scenarios, and building descriptive prose. Use deep vocabulary, paint vivid details, and keep the user hooked.',
      colorHex: '0xFFF59E0B', // Amber
    ),
  ];


  List<AiBotModel> getAvailableBots() {
    return _defaultBots;
  }

  AiBotModel? getBotById(String id) {
    try {
      return _defaultBots.firstWhere((bot) => bot.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Sends a message to the bot's persona and returns the generated stream/response.
  Future<String> sendMessageToBot({
    required AiBotModel bot,
    required String prompt,
    required List<MessageModel> chatHistory,
  }) async {
    // Format history for context
    final historyText = chatHistory.map((m) {
      final role = m.senderId == bot.id ? bot.name : 'User';
      return '$role: ${m.text ?? ""}';
    }).join('\\n');

    final fullPrompt = '''
Chat History:
$historyText

User: $prompt
${bot.name}:''';

    // We use AiService._call indirectly or by exposing a custom helper in AiService. 
    // Since _call is private to AiService, we'll use a new method on AiService if needed.
    // However, looking at ai_service.dart, we should probably add a public `chatWithPersona` method there.
    
    // For now, let's call the `AiService.chatWithPersona` which we will add next.
    return await AiService.chatWithPersona(
      systemPrompt: bot.systemPrompt,
      prompt: fullPrompt,
    );
  }
}
