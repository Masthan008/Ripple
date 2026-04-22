import 'package:flutter/material.dart';

/// Mood definitions for the Ripple Mood Aura system.
/// Each mood has an emoji, label, gradient colors, and animation style.
class MoodConfig {
  MoodConfig._();

  static const moods = {
    'happy': {
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'label': 'Happy',
      'colors': ['F59E0B', 'EF4444'],
      'animation': 'pulse',
    },
    'focused': {
      'icon': Icons.center_focus_strong_rounded,
      'label': 'Focused',
      'colors': ['0EA5E9', '6366F1'],
      'animation': 'glow',
    },
    'busy': {
      'icon': Icons.flash_on_rounded,
      'label': 'Busy',
      'colors': ['EF4444', 'F97316'],
      'animation': 'fast_pulse',
    },
    'gaming': {
      'icon': Icons.sports_esports_rounded,
      'label': 'Gaming',
      'colors': ['8B5CF6', 'EC4899'],
      'animation': 'rgb_cycle',
    },
    'vibing': {
      'icon': Icons.waves_rounded,
      'label': 'Vibing',
      'colors': ['0EA5E9', '22D3EE'],
      'animation': 'wave',
    },
  };

  /// Parse a hex color string (without #) to a Color
  static Color hexToColor(String hex) {
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Get gradient colors for a mood
  static List<Color> getColors(String mood) {
    final config = moods[mood];
    if (config == null) return [const Color(0xFF0EA5E9), const Color(0xFF22D3EE)];
    return (config['colors'] as List<String>)
        .map((c) => hexToColor(c))
        .toList();
  }

  /// Get icon for a mood
  static IconData getIcon(String mood) {
    return (moods[mood]?['icon'] as IconData?) ?? Icons.waves_rounded;
  }

  /// Get label for a mood
  static String getLabel(String mood) {
    return (moods[mood]?['label'] as String?) ?? 'Unknown';
  }
}
