import 'dart:async';

import 'package:flutter/material.dart';

import '../models/emotional_signature.dart';

/// Sensory Text Controller — Emotional Resonance™
///
/// A custom TextEditingController wrapper that passively captures
/// typing rhythm and intensity while the user composes a message.
///
/// Tracked metrics:
/// - Keystrokes per second (tempo)
/// - Burst vs. pause patterns
/// - Caps lock usage
/// - Emoji density
/// - Deletion frequency (backspace count)
///
/// When [captureSignature] is called (at send time), it returns
/// a frozen [EmotionalSignature] snapshot of the entire composition.
class SensoryTextController {
  final TextEditingController controller;

  // Raw tracking data
  DateTime? _compositionStart;
  int _totalKeystrokes = 0;
  int _deletionCount = 0;
  int _burstKeystrokes = 0; // keystrokes at >5 chars/sec
  String _previousText = '';

  // Timing
  DateTime? _lastKeystroke;
  final List<int> _pauseDurations = []; // ms between bursts
  int _burstFrames = 0; // consecutive fast keystrokes
  bool _inBurst = false;

  // Derived
  double _totalBurstTime = 0; // seconds spent in burst-typing

  SensoryTextController({required this.controller}) {
    controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final now = DateTime.now();
    final currentText = controller.text;

    // Start composition tracking on first keystroke
    _compositionStart ??= now;

    final isAddition = currentText.length > _previousText.length;
    final isDeletion = currentText.length < _previousText.length;

    if (isAddition) {
      final charsAdded = currentText.length - _previousText.length;
      _totalKeystrokes += charsAdded;

      if (_lastKeystroke != null) {
        final elapsed = now.difference(_lastKeystroke!).inMilliseconds;
        final charsPerSec = elapsed > 0 ? (charsAdded * 1000.0 / elapsed) : 0;

        if (charsPerSec > 5) {
          // Fast typing — in a burst
          _burstKeystrokes += charsAdded;
          _burstFrames++;
          if (!_inBurst) {
            // Transitioning from pause to burst
            if (_lastKeystroke != null) {
              _pauseDurations.add(elapsed);
            }
            _inBurst = true;
          }
          _totalBurstTime += elapsed / 1000.0;
        } else {
          // Slow typing — paused/thinking
          if (_inBurst) {
            _inBurst = false;
          }
          _burstFrames = 0;
        }
      }
    }

    if (isDeletion) {
      _deletionCount += (_previousText.length - currentText.length);
    }

    _lastKeystroke = now;
    _previousText = currentText;
  }

  /// Capture and return the emotional signature at send time.
  /// Resets the tracking state for the next message.
  EmotionalSignature captureSignature() {
    final text = controller.text;

    if (text.isEmpty || _compositionStart == null) {
      return const EmotionalSignature();
    }

    final now = DateTime.now();
    final compositionMs = now.difference(_compositionStart!).inMilliseconds;
    final compositionSec = compositionMs / 1000.0;

    // Tempo: characters per second
    final tempo = compositionSec > 0 ? text.length / compositionSec : 3.0;

    // Burst ratio: fraction of keystrokes that were in bursts
    final burstRatio = _totalKeystrokes > 0
        ? _burstKeystrokes / _totalKeystrokes
        : 0.0;

    // Average pause duration
    final avgPauseMs = _pauseDurations.isNotEmpty
        ? _pauseDurations.reduce((a, b) => a + b) / _pauseDurations.length
        : 500.0;

    // Caps ratio
    final upperCount = text.runes
        .where((c) => String.fromCharCode(c) ==
            String.fromCharCode(c).toUpperCase() &&
            String.fromCharCode(c) !=
            String.fromCharCode(c).toLowerCase())
        .length;
    final capsRatio = text.isNotEmpty ? upperCount / text.length : 0.0;

    // Emoji density (emojis per 100 characters)
    final emojiCount = _countEmojis(text);
    final emojiDensity = text.isNotEmpty ? (emojiCount * 100) / text.length : 0.0;

    // Deletion ratio
    final totalActions = _totalKeystrokes + _deletionCount;
    final deletionRatio = totalActions > 0
        ? _deletionCount / totalActions
        : 0.0;

    // Classify the tone
    final tone = classifyTone(
      tempo: tempo,
      burstRatio: burstRatio,
      avgPauseMs: avgPauseMs.toDouble(),
      capsRatio: capsRatio,
      emojiDensity: emojiDensity,
      deletionRatio: deletionRatio,
    );

    final signature = EmotionalSignature(
      tempo: tempo,
      burstRatio: burstRatio,
      avgPauseMs: avgPauseMs.toDouble(),
      capsRatio: capsRatio,
      emojiDensity: emojiDensity,
      deletionRatio: deletionRatio,
      compositionTimeMs: compositionMs,
      tone: tone,
    );

    // Reset for next message
    _reset();

    return signature;
  }

  void _reset() {
    _compositionStart = null;
    _totalKeystrokes = 0;
    _deletionCount = 0;
    _burstKeystrokes = 0;
    _previousText = '';
    _lastKeystroke = null;
    _pauseDurations.clear();
    _burstFrames = 0;
    _inBurst = false;
    _totalBurstTime = 0;
  }

  /// Count emoji characters in text
  int _countEmojis(String text) {
    // Match common emoji patterns using RegExp
    final emojiPattern = RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
      r'[\u{1F1E0}-\u{1F1FF}]|[\u{2702}-\u{27B0}]|[\u{24C2}-\u{1F251}]|'
      r'[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|[\u{1FA70}-\u{1FAFF}]|'
      r'[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
      unicode: true,
    );
    return emojiPattern.allMatches(text).length;
  }

  void dispose() {
    controller.removeListener(_onTextChanged);
  }
}
