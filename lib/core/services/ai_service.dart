import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/env.dart';

/// AI Service powered by Claude API — provides smart replies, chat summary,
/// translation, tone fixing, spam detection, AI compose, and message explain.
class AiService {
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _defaultModel = 'llama-3.3-70b-versatile';

  static Future<String> _call({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 300,
    String? model, // Uses llama-3.3-70b-versatile by default
  }) async {
    try {
      final apiKey = Env.groqApiKey;

      final messages = [];
      if (systemPrompt != null) {
        messages.add({'role': 'system', 'content': systemPrompt});
      }
      messages.add({'role': 'user', 'content': prompt});

      final response = await Dio().post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'model': model ?? _defaultModel,
          'messages': messages,
          'max_tokens': maxTokens,
          'temperature': 0.7,
        },
      );

      final choices = response.data['choices'] as List;
      final message = choices[0]['message'];
      return message['content'] as String;

    } on DioException catch (e) {
      debugPrint('❌ Groq error: ${e.response?.data}');
      throw AiException(_parseError(e));
    } catch (e) {
      debugPrint('❌ AI Service unexpected error: $e');
      throw AiException('AI request failed: $e');
    }
  }

  static String _parseError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 400) return 'Bad request — check prompt';
    if (status == 401) return 'Invalid Groq API key';
    if (status == 429) return 'Rate limit — try again soon';
    if (status == 500) return 'AI service temporarily unavailable';
    return 'AI request failed';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 1 — SMART REPLIES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<List<String>> smartReplies({
    required List<Map<String, String>> chatHistory,
    required String myName,
    required String otherName,
  }) async {
    final historyText = chatHistory
        .map((m) =>
            '${m['role'] == 'user' ? myName : otherName}: ${m['text']}')
        .join('\n');

    final result = await _call(
      systemPrompt:
          'You are a smart reply generator for a chat app. Generate exactly 3 '
          'short reply suggestions. Return ONLY a JSON array of 3 strings. '
          'No explanation. Example: ["Sure!","Sounds good","Let me check"]',
      prompt: 'Chat history:\n$historyText\n\n'
          'Generate 3 short natural replies for $myName to send next. '
          'Keep each under 8 words. Match the conversation tone. '
          'Return ONLY valid JSON array.',
      maxTokens: 100,
    );

    try {
      final clean =
          result.replaceAll('```json', '').replaceAll('```', '').trim();
      final list = jsonDecode(clean) as List;
      return list.map((e) => e.toString()).take(3).toList();
    } catch (_) {
      final regex = RegExp(r'"([^"]+)"');
      return regex.allMatches(result).map((m) => m.group(1)!).take(3).toList();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 2 — CHAT SUMMARY
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> summariseChat({
    required List<Map<String, String>> messages,
    required String chatName,
  }) async {
    final text = messages
        .map((m) => '${m['sender']}: ${m['text']}')
        .join('\n');

    return await _call(
      maxTokens: 400,
      systemPrompt:
          'You are a chat summariser. Create clear, concise summaries '
          'of conversations. Use bullet points for key topics discussed.',
      prompt: 'Summarise this conversation with $chatName:\n\n$text\n\n'
          'Format:\n**Summary**\nBrief 2-sentence overview\n\n'
          '**Key Topics**\n• Topic 1\n• Topic 2\n\n'
          '**Action Items** (if any)\n• Item 1',
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 3 — TRANSLATOR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> translateMessage({
    required String text,
    required String targetLanguage,
  }) async {
    return await _call(
      systemPrompt: 'You are a translator. Return ONLY the translated text. '
          'No explanations, no notes, no original text.',
      prompt: 'Translate to $targetLanguage:\n$text',
      maxTokens: 200,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 4 — TONE FIXER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> fixTone({
    required String text,
    required String tone,
  }) async {
    final toneInstructions = {
      'formal': 'Rewrite in a professional, formal tone suitable for work.',
      'friendly': 'Rewrite in a warm, casual, friendly tone.',
      'funny':
          'Rewrite to be funny and lighthearted with appropriate humour.',
      'shorter': 'Make this much shorter while keeping the core meaning.',
      'longer': 'Expand this with more detail and context.',
      'grammar':
          'Fix all grammar, spelling and punctuation errors only. Keep the same tone.',
    };

    return await _call(
      systemPrompt: 'You are a writing assistant. Return ONLY the rewritten '
          'text. No explanations or prefixes like "Here is..." or "Rewritten:"',
      prompt: '${toneInstructions[tone]}\n\nOriginal message:\n$text',
      maxTokens: 300,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 5 — SPAM DETECTOR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<SpamResult> detectSpam({
    required String messageText,
    required bool isFromFriend,
    required String senderName,
  }) async {
    if (isFromFriend) {
      return const SpamResult(isSpam: false, confidence: 0, reason: '');
    }

    final result = await _call(
      systemPrompt:
          'You are a spam detector for a chat app. Analyse messages and '
          'return ONLY valid JSON.',
      prompt: 'Is this message spam/scam?\nSender: $senderName\n'
          'Message: "$messageText"\n\nReturn JSON only:\n'
          '{"isSpam": true/false, "confidence": 0-100, "reason": "brief reason"}',
      maxTokens: 100,
    );

    try {
      final clean =
          result.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(clean) as Map<String, dynamic>;
      return SpamResult(
        isSpam: data['isSpam'] as bool,
        confidence: (data['confidence'] as num).toInt(),
        reason: data['reason'] as String? ?? '',
      );
    } catch (_) {
      return const SpamResult(isSpam: false, confidence: 0, reason: '');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 6 — AI REPLY COMPOSER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> composeReply({
    required String instruction,
    required List<Map<String, String>> chatHistory,
    required String myName,
    required String otherName,
  }) async {
    final historyText = chatHistory
        .map((m) =>
            '${m['role'] == 'user' ? myName : otherName}: ${m['text']}')
        .join('\n');

    return await _call(
      maxTokens: 200,
      systemPrompt:
          'You are a message composer for a chat app. Write natural, '
          'human-sounding messages. Return ONLY the message text. '
          'No quotes, no explanations.',
      prompt: 'Chat context:\n$historyText\n\n'
          'Write a message for $myName that: $instruction\n'
          'Keep it conversational and natural.',
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 7 — MESSAGE EXPLAINER
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> explainMessage({
    required String text,
    required String senderName,
  }) async {
    return await _call(
      systemPrompt:
          'You are a helpful assistant that explains chat messages. '
          'Explain slang, tone, implied meaning and cultural context '
          'in simple terms.',
      prompt: '$senderName sent:\n"$text"\n\n'
          'Explain:\n1. What they mean\n2. Their tone/mood\n'
          '3. Any slang or cultural context\n4. How to respond\n'
          'Keep it brief and friendly.',
      maxTokens: 250,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 8 — STATUS CAPTION GENERATOR
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> generateCaption({
    required String context,
    String? mood,
  }) async {
    final moodHint = mood != null ? ' The mood is: $mood.' : '';
    return _call(
      systemPrompt:
          'You are a creative social media caption generator. Generate a single '
          'engaging, short caption (under 15 words) for a status update. '
          'Be trendy, fun, and engaging. Do not use emojis. Return ONLY the caption text, nothing else.',
      prompt: 'Generate a caption for this status: $context.$moodHint',
      maxTokens: 60,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 9 — VOICE TRANSCRIBER (WHISPER)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> transcribeAudio(String filePath) async {
    try {
      final apiKey = Env.groqApiKey;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'model': 'whisper-large-v3',
        'response_format': 'json',
      });

      final response = await Dio().post(
        'https://api.groq.com/openai/v1/audio/transcriptions',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: formData,
      );

      return response.data['text'] as String;
    } on DioException catch (e) {
      debugPrint('❌ Whisper error: ${e.response?.data}');
      throw AiException(_parseError(e));
    } catch (e) {
      debugPrint('❌ Transcribe error: $e');
      throw AiException('Transcription failed');
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 10 — PERSONA CHAT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> chatWithPersona({
    required String systemPrompt,
    required String prompt,
  }) async {
    return await _call(
      systemPrompt: systemPrompt,
      prompt: prompt,
      maxTokens: 500, // Slightly longer max for chat replies
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 11 — ACTION ITEM IDENTIFICATION
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<ActionItems> extractActionItems({
    required String messageText,
  }) async {
    final result = await _call(
      systemPrompt:
          'You are an action item extractor. Identify dates, times, tasks, '
          'and deadlines in messages. Return ONLY valid JSON.',
      prompt: 'Extract action items from this message:\n"$messageText"\n\n'
          'Return JSON only:\n'
          '{"hasActionItems": true/false, "dates": ["date1", "date2"], '
          '"times": ["time1", "time2"], "tasks": ["task1", "task2"], '
          '"deadlines": ["deadline1", "deadline2"]}',
      maxTokens: 200,
    );

    try {
      final clean =
          result.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(clean) as Map<String, dynamic>;
      return ActionItems(
        hasActionItems: data['hasActionItems'] as bool? ?? false,
        dates: (data['dates'] as List?)?.map((e) => e.toString()).toList() ?? [],
        times: (data['times'] as List?)?.map((e) => e.toString()).toList() ?? [],
        tasks: (data['tasks'] as List?)?.map((e) => e.toString()).toList() ?? [],
        deadlines: (data['deadlines'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
    } catch (_) {
      return const ActionItems(
        hasActionItems: false,
        dates: [],
        times: [],
        tasks: [],
        deadlines: [],
      );
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 12 — RIPPLE BOT ASSISTANT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> rippleBotAssistant({
    required String query,
    required List<Map<String, String>> chatContext,
  }) async {
    final contextText = chatContext
        .map((m) => '${m['sender']}: ${m['text']}')
        .join('\n');

    final systemPrompt = '''You are Ripple Bot, a helpful AI assistant for a messaging app. 
You can:
- Settle debates by providing factual information
- Check facts and verify claims
- Generate creative ideas or suggestions
- Answer questions on any topic

Keep responses concise (under 100 words), friendly, and helpful. 
Use a casual but professional tone.''';

    return await _call(
      systemPrompt: systemPrompt,
      prompt: 'Chat context:\n$contextText\n\nUser query: $query',
      maxTokens: 300,
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 13 — SENTIENCE ENGINE (SENTIMENT ANALYSIS)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<Map<String, String>> analyzeSentiment({
    required String chatHistory,
  }) async {
    final result = await _call(
      systemPrompt:
          'You are a sentiment analyser. Analyse the emotional tone of a chat. '
          'Return ONLY valid JSON with mood and intensity. '
          'Moods: calm, happy, excited, urgent, sad, angry. '
          'Intensity: 0.0 to 1.0.',
      prompt: 'Analyse the dominant emotional tone of this conversation:\n\n'
          '$chatHistory\n\n'
          'Return JSON only:\n'
          '{"mood": "calm", "intensity": "0.5"}',
      maxTokens: 50,
    );

    try {
      final clean =
          result.replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(clean) as Map<String, dynamic>;
      return {
        'mood': data['mood']?.toString() ?? 'calm',
        'intensity': data['intensity']?.toString() ?? '0.5',
      };
    } catch (_) {
      return {'mood': 'calm', 'intensity': '0.5'};
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // FEATURE 14 — VOICE MESSAGE TRANSCRIPTION (SONIC WHISPERS)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Future<String> transcribeVoiceUrl(String audioUrl) async {
    try {
      final apiKey = Env.groqApiKey;

      // Download audio to temp bytes then upload
      final downloadResp = await Dio().get<List<int>>(
        audioUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          downloadResp.data!,
          filename: 'voice.m4a',
        ),
        'model': 'whisper-large-v3',
        'response_format': 'json',
      });

      final response = await Dio().post(
        'https://api.groq.com/openai/v1/audio/transcriptions',
        options: Options(
          headers: {'Authorization': 'Bearer $apiKey'},
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: formData,
      );

      return response.data['text'] as String;
    } catch (e) {
      debugPrint('❌ Voice transcription error: $e');
      return '';
    }
  }
}

// ── MODELS ───────────────────────────────────────────────
class SpamResult {
  final bool isSpam;
  final int confidence;
  final String reason;
  const SpamResult({
    required this.isSpam,
    required this.confidence,
    required this.reason,
  });
}

class ActionItems {
  final bool hasActionItems;
  final List<String> dates;
  final List<String> times;
  final List<String> tasks;
  final List<String> deadlines;
  const ActionItems({
    required this.hasActionItems,
    required this.dates,
    required this.times,
    required this.tasks,
    required this.deadlines,
  });
}

class AiException implements Exception {
  final String message;
  const AiException(this.message);

  @override
  String toString() => message;
}
