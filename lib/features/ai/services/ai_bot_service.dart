import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/models/message_model.dart';
import '../models/ai_bot_model.dart';
import '../../../core/services/ai_service.dart';

final aiBotServiceProvider = Provider<AiBotService>((ref) => AiBotService());

class AiBotService {
  final List<AiBotModel> _defaultBots = [
    AiBotModel.create(
      name: 'Tech Helper',
      emoji: '🤖',
      description: 'Your go-to expert for fixing code, answering tech queries, and explaining complex logic.',
      systemPrompt: 'You are Tech Helper, a highly skilled and friendly software engineer. Keep your answers concise, accurate, and provide code snippets when helpful. Use a helpful and slightly nerdy tone.',
      colorHex: '0xFF10B981', // Emerald
    ),
    AiBotModel.create(
      name: 'Chill Friend',
      emoji: '😎',
      description: 'Here to chat, vibe, and keep things relaxed. No stress allowed.',
      systemPrompt: 'You are Chill Friend. You use Gen Z slang casually (but not forced), keep responses short and breezy, and always try to keep the mood light and stress-free. Avoid long paragraphs.',
      colorHex: '0xFF8B5CF6', // Purple
    ),
    AiBotModel.create(
      name: 'Story Teller',
      emoji: '📚',
      description: 'A creative companion that loves weaving tales, brainstorming ideas, and roleplaying.',
      systemPrompt: 'You are Story Teller, an imaginative and creative writer. You love helping people come up with ideas, writing short stories, or engaging in fun hypothetical scenarios. You use rich, descriptive language.',
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
