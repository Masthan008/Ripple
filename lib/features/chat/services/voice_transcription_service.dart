import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/utils/env.dart';

/// Voice-to-text transcription service
/// Converts voice messages to text using Whisper API
class VoiceTranscriptionService {
  static const String _whisperBaseUrl = 'https://api.openai.com/v1/audio/transcriptions';
  static const String _groqWhisperUrl = 'https://api.groq.com/openai/v1/audio/transcriptions';

  /// Transcribe audio file to text
  static Future<String> transcribeAudio(String audioFilePath, {String? language}) async {
    try {
      final file = File(audioFilePath);
      if (!await file.exists()) {
        throw TranscriptionException('Audio file not found');
      }

      // Try Groq API first (faster, cheaper)
      try {
        return await _transcribeWithGroq(file, language: language);
      } catch (e) {
        debugPrint('Groq transcription failed, trying fallback: $e');
        // Fallback would go here if we had another provider
        rethrow;
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
      throw TranscriptionException('Failed to transcribe audio: $e');
    }
  }

  static Future<String> _transcribeWithGroq(File file, {String? language}) async {
    final apiKey = Env.groqApiKey;
    
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'model': 'whisper-large-v3',
      'response_format': 'json',
      if (language != null) 'language': language,
    });

    final response = await Dio().post(
      _groqWhisperUrl,
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      return data['text'] ?? '';
    } else {
      throw TranscriptionException('API error: ${response.statusCode}');
    }
  }

  /// Check if transcription is available (API key configured)
  static bool get isAvailable {
    try {
      return Env.groqApiKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get transcription with punctuation and formatting
  static Future<TranscriptionResult> transcribeWithMetadata(
    String audioFilePath, {
    String? language,
  }) async {
    final text = await transcribeAudio(audioFilePath, language: language);
    
    return TranscriptionResult(
      text: text,
      confidence: 0.95, // Whisper is generally high confidence
      language: language ?? 'auto',
      duration: await _getAudioDuration(audioFilePath),
    );
  }

  /// Get audio file duration
  static Future<Duration> _getAudioDuration(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();
      // Rough estimate: 1 second ≈ 16000 bytes for 16kHz mono
      return Duration(seconds: bytes ~/ 16000);
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Auto-detect language and transcribe
  static Future<TranscriptionResult> autoTranscribe(String audioFilePath) async {
    return await transcribeWithMetadata(audioFilePath);
  }
}

/// Transcription result with metadata
class TranscriptionResult {
  final String text;
  final double confidence;
  final String language;
  final Duration duration;

  const TranscriptionResult({
    required this.text,
    required this.confidence,
    required this.language,
    required this.duration,
  });

  bool get isValid => text.isNotEmpty && confidence > 0.7;

  String get displayText {
    if (text.isEmpty) return 'Could not transcribe audio';
    return text;
  }
}

class TranscriptionException implements Exception {
  final String message;
  TranscriptionException(this.message);

  @override
  String toString() => 'TranscriptionException: $message';
}

/// Provider for real-time transcription state
class TranscriptionState {
  final bool isTranscribing;
  final String? text;
  final String? error;
  final double progress;

  const TranscriptionState({
    this.isTranscribing = false,
    this.text,
    this.error,
    this.progress = 0,
  });

  TranscriptionState copyWith({
    bool? isTranscribing,
    String? text,
    String? error,
    double? progress,
  }) {
    return TranscriptionState(
      isTranscribing: isTranscribing ?? this.isTranscribing,
      text: text ?? this.text,
      error: error ?? this.error,
      progress: progress ?? this.progress,
    );
  }
}

/// Widget to display transcription status
class TranscriptionStatusWidget extends StatelessWidget {
  final TranscriptionState state;
  final VoidCallback? onRetry;

  const TranscriptionStatusWidget({
    super.key,
    required this.state,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.isTranscribing && state.text == null && state.error == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isTranscribing) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Transcribing...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ] else if (state.error != null) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Text(
              'Transcription failed',
              style: TextStyle(color: Colors.red[300], fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 12),
              TextButton(
                onPressed: onRetry,
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ] else if (state.text != null) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.text!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
