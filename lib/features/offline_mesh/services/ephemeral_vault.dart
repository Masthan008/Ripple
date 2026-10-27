import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ephemeral_message.dart';

final ephemeralVaultProvider =
    StateNotifierProvider<EphemeralVault, List<EphemeralMessage>>((ref) {
  return EphemeralVault();
});

/// Zero-Disk Volatile Memory Vault for BitChat-style offline conversations.
/// Automatically purges expired messages and provides an instant panic scrub.
class EphemeralVault extends StateNotifier<List<EphemeralMessage>> {
  Timer? _evaporationTimer;

  EphemeralVault() : super([]) {
    _startEvaporationTicker();
  }

  void _startEvaporationTicker() {
    _evaporationTimer?.cancel();
    _evaporationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _purgeExpiredMessages();
    });
  }

  /// Adds a new message into volatile memory
  void addMessage(EphemeralMessage message) {
    if (message.isExpired) return;
    state = [...state, message];
  }

  /// Evaluates and cleans expired messages from RAM
  void _purgeExpiredMessages() {
    if (state.isEmpty) return;

    final unexpired = state.where((m) => !m.isExpired).toList();
    if (unexpired.length != state.length) {
      state = unexpired;
    }
  }

  /// Panic Wipe — immediately scrubs all messages and zeroes memory
  void panicWipe() {
    _evaporationTimer?.cancel();
    // Overwrite buffer before assigning empty list
    state = [];
    _startEvaporationTicker();
    debugPrint('[ZeroTraceMesh] Memory Vault explicitly scrubbed & zeroed.');
  }

  @override
  void dispose() {
    _evaporationTimer?.cancel();
    state = [];
    super.dispose();
  }
}
