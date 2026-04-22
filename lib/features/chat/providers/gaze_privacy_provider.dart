import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/gaze_privacy_service.dart';

// ─── Telepathy Enabled Provider ─────────────────────────
/// Whether Ripple Telepathy™ is enabled by the user.
final telepathyEnabledProvider =
    StateNotifierProvider<TelepathyEnabledNotifier, bool>((ref) {
  return TelepathyEnabledNotifier();
});

class TelepathyEnabledNotifier extends StateNotifier<bool> {
  TelepathyEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('telepathy_enabled') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('telepathy_enabled', state);
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('telepathy_enabled', value);
  }
}

// ─── Gaze Privacy State Provider ────────────────────────
/// Streams the real-time gaze privacy state from the camera pipeline.
/// Only active when telepathy is enabled.
final gazePrivacyStateProvider =
    StreamProvider.autoDispose<GazePrivacyState>((ref) {
  final isEnabled = ref.watch(telepathyEnabledProvider);

  if (!isEnabled) {
    // Return a stream that always says "show messages"
    return Stream.value(const GazePrivacyState(
      isUserPresent: true,
      isShoulderSurferDetected: false,
      eyeOpenProbability: 1.0,
    ));
  }

  final service = GazePrivacyService.instance;

  // Initialize the camera pipeline if not already done
  if (!service.isInitialized) {
    service.initialize();
  }

  // When provider is disposed (user leaves chat), clean up
  ref.onDispose(() {
    service.dispose();
  });

  return service.stateStream;
});

// ─── Should Show Messages Provider ─────────────────────
/// Convenience provider: true when messages should be readable.
final shouldShowMessagesProvider = Provider.autoDispose<bool>((ref) {
  final isEnabled = ref.watch(telepathyEnabledProvider);
  if (!isEnabled) return true; // Feature off → always show

  final gazeState = ref.watch(gazePrivacyStateProvider);
  return gazeState.when(
    data: (state) => state.shouldShowMessages,
    loading: () => false, // Blur while initializing
    error: (_, __) => true, // Show on error (graceful degradation)
  );
});

// ─── Shoulder Surfer Detected Provider ─────────────────
/// true when a second face is detected — triggers full-screen lockdown.
final shoulderSurferDetectedProvider = Provider.autoDispose<bool>((ref) {
  final isEnabled = ref.watch(telepathyEnabledProvider);
  if (!isEnabled) return false;

  final gazeState = ref.watch(gazePrivacyStateProvider);
  return gazeState.when(
    data: (state) => state.isShoulderSurferDetected,
    loading: () => false,
    error: (_, __) => false,
  );
});
