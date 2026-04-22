import 'dart:math';

/// Emotional Signature Model — Emotional Resonance™
///
/// Captures the typing rhythm, intensity, and emotional cadence
/// of a message as it's being composed. This metadata is stored
/// alongside the message and played back as haptic patterns +
/// visual animations on the recipient's device.
///
/// The signature captures:
/// - **tempo**: Average characters per second (typing speed)
/// - **burstRatio**: How much of the typing came in rapid bursts
/// - **pausePattern**: Distribution of pauses during composition
/// - **capsRatio**: Ratio of uppercase characters (emphasis/shouting)
/// - **emojiDensity**: Emoji usage density
/// - **deletionRatio**: How much backspacing occurred (hesitation)
/// - **emotionalTone**: Derived emotional classification
class EmotionalSignature {
  /// Average characters typed per second
  final double tempo;

  /// Ratio of burst-typing (>5 chars/sec) vs total typing time (0.0-1.0)
  final double burstRatio;

  /// Average pause duration in milliseconds between typing bursts
  final double avgPauseMs;

  /// Ratio of uppercase characters (0.0-1.0)
  final double capsRatio;

  /// Number of emojis per 100 characters
  final double emojiDensity;

  /// Ratio of deletions to total keystrokes (0.0-1.0)
  final double deletionRatio;

  /// Total composition time in milliseconds
  final int compositionTimeMs;

  /// Derived emotional tone
  final EmotionalTone tone;

  const EmotionalSignature({
    this.tempo = 3.0,
    this.burstRatio = 0.0,
    this.avgPauseMs = 500.0,
    this.capsRatio = 0.0,
    this.emojiDensity = 0.0,
    this.deletionRatio = 0.0,
    this.compositionTimeMs = 0,
    this.tone = EmotionalTone.neutral,
  });

  /// Create from Firestore map
  factory EmotionalSignature.fromMap(Map<String, dynamic> data) {
    return EmotionalSignature(
      tempo: (data['tempo'] as num?)?.toDouble() ?? 3.0,
      burstRatio: (data['burstRatio'] as num?)?.toDouble() ?? 0.0,
      avgPauseMs: (data['avgPauseMs'] as num?)?.toDouble() ?? 500.0,
      capsRatio: (data['capsRatio'] as num?)?.toDouble() ?? 0.0,
      emojiDensity: (data['emojiDensity'] as num?)?.toDouble() ?? 0.0,
      deletionRatio: (data['deletionRatio'] as num?)?.toDouble() ?? 0.0,
      compositionTimeMs: data['compositionTimeMs'] as int? ?? 0,
      tone: EmotionalTone.fromString(data['tone'] as String? ?? 'neutral'),
    );
  }

  /// Convert to Firestore-safe map
  Map<String, dynamic> toMap() {
    return {
      'tempo': tempo,
      'burstRatio': burstRatio,
      'avgPauseMs': avgPauseMs,
      'capsRatio': capsRatio,
      'emojiDensity': emojiDensity,
      'deletionRatio': deletionRatio,
      'compositionTimeMs': compositionTimeMs,
      'tone': tone.name,
    };
  }

  /// Get the intensity level (0.0-1.0) for haptic/animation strength.
  double get intensity {
    // Combine multiple signals for overall intensity
    final speedFactor = (tempo / 8.0).clamp(0.0, 1.0); // Fast typing
    final burstFactor = burstRatio; // Burst patterns
    final capsFactor = capsRatio * 2; // SHOUTING
    final emojiFactor = (emojiDensity / 10).clamp(0.0, 1.0); // Expressive

    return ((speedFactor + burstFactor + capsFactor + emojiFactor) / 4)
        .clamp(0.0, 1.0);
  }

  /// Get the animation duration multiplier (lower = faster animations)
  double get animationSpeedMultiplier {
    // High tempo → faster animations, low tempo → slower/calmer
    return (1.5 - intensity).clamp(0.5, 1.5);
  }
}

/// Emotional tone classifications derived from typing patterns
enum EmotionalTone {
  /// Calm, measured typing — normal conversation
  neutral,

  /// Fast burst typing — excitement, urgency
  excited,

  /// LOTS OF CAPS + fast typing — emphasis, passion
  emphatic,

  /// Slow with many pauses — thoughtful, careful
  thoughtful,

  /// Fast with many deletions — anxious, uncertain
  hesitant,

  /// Heavy emoji usage — playful, expressive
  playful,

  /// Very fast, minimal pauses — urgent, important
  urgent;

  static EmotionalTone fromString(String value) {
    return EmotionalTone.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EmotionalTone.neutral,
    );
  }

  /// Emoji representation of the tone
  String get emoji {
    switch (this) {
      case EmotionalTone.neutral:
        return '😌';
      case EmotionalTone.excited:
        return '🤩';
      case EmotionalTone.emphatic:
        return '🔥';
      case EmotionalTone.thoughtful:
        return '🤔';
      case EmotionalTone.hesitant:
        return '😬';
      case EmotionalTone.playful:
        return '😜';
      case EmotionalTone.urgent:
        return '⚡';
    }
  }

  /// Human-readable label
  String get label {
    switch (this) {
      case EmotionalTone.neutral:
        return 'Calm';
      case EmotionalTone.excited:
        return 'Excited';
      case EmotionalTone.emphatic:
        return 'Fired Up';
      case EmotionalTone.thoughtful:
        return 'Thoughtful';
      case EmotionalTone.hesitant:
        return 'Hesitant';
      case EmotionalTone.playful:
        return 'Playful';
      case EmotionalTone.urgent:
        return 'Urgent';
    }
  }
}

/// Classifies the emotional tone from raw metrics.
EmotionalTone classifyTone({
  required double tempo,
  required double burstRatio,
  required double avgPauseMs,
  required double capsRatio,
  required double emojiDensity,
  required double deletionRatio,
}) {
  // Urgent: very fast, no pauses
  if (tempo > 7 && avgPauseMs < 200 && burstRatio > 0.7) {
    return EmotionalTone.urgent;
  }

  // Emphatic: lots of caps + fast
  if (capsRatio > 0.3 && tempo > 4) {
    return EmotionalTone.emphatic;
  }

  // Excited: fast with bursts
  if (tempo > 5 && burstRatio > 0.5) {
    return EmotionalTone.excited;
  }

  // Playful: lots of emojis
  if (emojiDensity > 5) {
    return EmotionalTone.playful;
  }

  // Hesitant: many deletions + slow
  if (deletionRatio > 0.3 && tempo < 3) {
    return EmotionalTone.hesitant;
  }

  // Thoughtful: slow with long pauses
  if (tempo < 2 && avgPauseMs > 1500) {
    return EmotionalTone.thoughtful;
  }

  return EmotionalTone.neutral;
}
