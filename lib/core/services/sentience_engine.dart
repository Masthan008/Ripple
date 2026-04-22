import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_service.dart';

/// Sentience Engine™ — Real-time emotional environment adaptation
/// Analyzes the sentiment of a conversation and outputs visual parameters
/// that shift the chat UI (colors, shapes, haptics) accordingly.

class SentienceState {
  final String mood;        // calm, happy, excited, urgent, sad, angry
  final double intensity;   // 0.0 – 1.0
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color accentGlow;
  final double bubbleRoundness; // 0.0 (sharp) – 1.0 (pill)
  final double animationSpeed; // 0.5 (slow) – 2.0 (fast)

  const SentienceState({
    this.mood = 'calm',
    this.intensity = 0.0,
    this.primaryGlow = const Color(0xFF0EA5E9),
    this.secondaryGlow = const Color(0xFF6366F1),
    this.accentGlow = const Color(0xFF22D3EE),
    this.bubbleRoundness = 1.0,
    this.animationSpeed = 1.0,
  });

  /// Predefined mood palettes
  static SentienceState fromMood(String mood, double intensity) {
    switch (mood) {
      case 'happy':
        return SentienceState(
          mood: mood,
          intensity: intensity,
          primaryGlow: const Color(0xFF10B981),   // emerald
          secondaryGlow: const Color(0xFF34D399), // lighter green
          accentGlow: const Color(0xFF6EE7B7),    // mint
          bubbleRoundness: 1.0,
          animationSpeed: 1.2,
        );
      case 'excited':
        return SentienceState(
          mood: mood,
          intensity: intensity,
          primaryGlow: const Color(0xFFF59E0B),   // amber
          secondaryGlow: const Color(0xFFF97316), // orange
          accentGlow: const Color(0xFFEF4444),    // red
          bubbleRoundness: 0.6,
          animationSpeed: 1.8,
        );
      case 'urgent':
        return SentienceState(
          mood: mood,
          intensity: intensity,
          primaryGlow: const Color(0xFFEF4444),   // red
          secondaryGlow: const Color(0xFFF97316), // orange
          accentGlow: const Color(0xFFFBBF24),    // yellow
          bubbleRoundness: 0.3,
          animationSpeed: 2.0,
        );
      case 'sad':
        return SentienceState(
          mood: mood,
          intensity: intensity,
          primaryGlow: const Color(0xFF6366F1),   // indigo
          secondaryGlow: const Color(0xFF8B5CF6), // violet
          accentGlow: const Color(0xFF3B82F6),    // blue
          bubbleRoundness: 0.9,
          animationSpeed: 0.6,
        );
      case 'angry':
        return SentienceState(
          mood: mood,
          intensity: intensity,
          primaryGlow: const Color(0xFFDC2626),   // deep red
          secondaryGlow: const Color(0xFF991B1B), // dark red
          accentGlow: const Color(0xFFF87171),    // light red
          bubbleRoundness: 0.2,
          animationSpeed: 1.5,
        );
      case 'calm':
      default:
        return SentienceState(
          mood: 'calm',
          intensity: intensity,
          primaryGlow: const Color(0xFF0EA5E9),   // sky blue
          secondaryGlow: const Color(0xFF6366F1), // indigo
          accentGlow: const Color(0xFF22D3EE),    // cyan
          bubbleRoundness: 1.0,
          animationSpeed: 1.0,
        );
    }
  }
}

/// Provider for per-chat sentience state
/// Key: chatId → SentienceState
final sentienceProvider =
    StateNotifierProvider.family<SentienceNotifier, SentienceState, String>(
  (ref, chatId) => SentienceNotifier(),
);

class SentienceNotifier extends StateNotifier<SentienceState> {
  SentienceNotifier() : super(const SentienceState());

  String? _lastAnalyzedMsgId;
  bool _isAnalyzing = false;

  /// Called with the latest messages to analyze sentiment
  Future<void> analyze(List<Map<String, String>> recentMessages, String? lastMsgId) async {
    // Don't re-analyze the same message
    if (lastMsgId == _lastAnalyzedMsgId) return;
    if (_isAnalyzing) return;
    if (recentMessages.isEmpty) return;

    _lastAnalyzedMsgId = lastMsgId;
    _isAnalyzing = true;

    try {
      final historyText = recentMessages
          .map((m) => '${m['sender']}: ${m['text']}')
          .join('\n');

      final result = await AiService.analyzeSentiment(chatHistory: historyText);
      state = SentienceState.fromMood(result['mood']!, double.tryParse(result['intensity'] ?? '0.5') ?? 0.5);
    } catch (e) {
      debugPrint('Sentience Engine error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  void reset() {
    state = const SentienceState();
    _lastAnalyzedMsgId = null;
  }
}
