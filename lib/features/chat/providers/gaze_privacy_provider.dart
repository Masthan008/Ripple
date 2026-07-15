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

// ─── Anti-Shoulder Surfing Enabled Provider ─────────────
/// Whether Anti-Shoulder Surfing detection is independently enabled.
final antiShoulderSurfingEnabledProvider =
    StateNotifierProvider<AntiShoulderSurfingEnabledNotifier, bool>((ref) {
  return AntiShoulderSurfingEnabledNotifier();
});

class AntiShoulderSurfingEnabledNotifier extends StateNotifier<bool> {
  AntiShoulderSurfingEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('anti_shoulder_surfing_enabled') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('anti_shoulder_surfing_enabled', state);
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('anti_shoulder_surfing_enabled', value);
  }
}

/// Whether EITHER telepathy or anti-shoulder surfing is on (camera needed).
final cameraNeededProvider = Provider<bool>((ref) {
  return ref.watch(telepathyEnabledProvider) ||
      ref.watch(antiShoulderSurfingEnabledProvider);
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
  final gazeEnabled = ref.watch(telepathyEnabledProvider);
  final shoulderEnabled = ref.watch(antiShoulderSurfingEnabledProvider);

  // If neither feature is enabled, no camera needed
  if (!gazeEnabled && !shoulderEnabled) {
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
/// Gaze lock blurs if user isn't looking; shoulder surfing blurs if extra face detected.
final shouldShowMessagesProvider = Provider.autoDispose<bool>((ref) {
  final gazeEnabled = ref.watch(telepathyEnabledProvider);
  final shoulderEnabled = ref.watch(antiShoulderSurfingEnabledProvider);

  // Neither feature on → always show
  if (!gazeEnabled && !shoulderEnabled) return true;

  final gazeState = ref.watch(gazePrivacyStateProvider);
  return gazeState.when(
    data: (state) {
      // If shoulder surfing is enabled and a surfer is detected → hide
      if (shoulderEnabled && state.isShoulderSurferDetected) return false;
      // If gaze lock is enabled and user isn't looking → hide
      if (gazeEnabled && !state.isUserPresent) return false;
      // Otherwise show
      return true;
    },
    loading: () => false, // Blur while initializing
    error: (_, __) => true, // Show on error (graceful degradation)
  );
});

// ─── Shoulder Surfer Detected Provider ─────────────────
/// true when a second face is detected — triggers full-screen lockdown.
/// Only active when the anti-shoulder surfing toggle is independently on.
final shoulderSurferDetectedProvider = Provider.autoDispose<bool>((ref) {
  final shoulderEnabled = ref.watch(antiShoulderSurfingEnabledProvider);
  if (!shoulderEnabled) return false;

  final gazeState = ref.watch(gazePrivacyStateProvider);
  return gazeState.when(
    data: (state) => state.isShoulderSurferDetected,
    loading: () => false,
    error: (_, __) => false,
  );
});
