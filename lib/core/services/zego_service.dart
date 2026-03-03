import '../utils/env.dart';

/// ZegoCloud service for video & audio calls
/// Full implementation in Phase 8
class ZegoService {
  ZegoService._();

  static int get appId => int.tryParse(Env.zegoAppId) ?? 0;
  static String get appSign => Env.zegoAppSign;

  /// Initialize ZegoCloud (called when needed)
  static Future<void> initialize() async {
    // TODO: Phase 8 — Initialize ZegoCloud UIKit
  }

  /// Start a 1-to-1 video call
  static Future<void> startVideoCall({
    required String callId,
    required String userId,
    required String userName,
  }) async {
    // TODO: Phase 8 — Implement via zego_uikit_prebuilt_call
  }

  /// Start a group video call
  static Future<void> startGroupCall({
    required String callId,
    required String groupId,
    required String userId,
    required String userName,
  }) async {
    // TODO: Phase 8
  }
}
