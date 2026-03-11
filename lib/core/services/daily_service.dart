import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/env.dart';

/// Daily.co service — creates/manages rooms via REST API.
class DailyService {
  static const _baseUrl = 'https://api.daily.co/v1';

  static Dio get _dio => Dio(BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          'Authorization': 'Bearer ${Env.dailyApiKey}',
          'Content-Type': 'application/json',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

  /// Create a Daily.co room and return the room URL.
  static Future<String?> createRoom(String roomName) async {
    final apiKey = Env.dailyApiKey;
    if (apiKey.isEmpty) {
      debugPrint('⚠️ DAILY_API_KEY not set in .env');
      return null;
    }

    // Clean room name — Daily.co only allows alphanumeric + hyphens
    final cleanName = roomName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '-')
        .toLowerCase();

    try {
      final response = await _dio.post('/rooms', data: {
        'name': cleanName,
        'privacy': 'public',
        'properties': {
          'exp': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'enable_chat': true,
          'enable_screenshare': false,
          'start_video_off': false,
          'start_audio_off': false,
        },
      });

      final url = response.data['url'] as String?;
      debugPrint('✅ Daily.co room created: $url');
      return url;
    } on DioException catch (e) {
      // Room might already exist — try to get it
      if (e.response?.statusCode == 400) {
        try {
          final getResp = await _dio.get('/rooms/$cleanName');
          final url = getResp.data['url'] as String?;
          debugPrint('✅ Daily.co room already exists: $url');
          return url;
        } catch (_) {}
      }
      debugPrint('❌ Daily.co error: ${e.response?.data ?? e.message}');
      return null;
    }
  }

  /// Delete a Daily.co room.
  static Future<void> deleteRoom(String roomName) async {
    final cleanName = roomName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '-')
        .toLowerCase();
    try {
      await _dio.delete('/rooms/$cleanName');
    } catch (e) {
      debugPrint('⚠️ Failed to delete room: $e');
    }
  }
}
