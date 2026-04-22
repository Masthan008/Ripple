import 'package:flutter/material.dart';

class ReactionIcons {
  static const Map<String, IconData> _icons = {
    'favorite': Icons.favorite_rounded,
    '❤️': Icons.favorite_rounded,
    'laugh': Icons.sentiment_very_satisfied_rounded,
    '😂': Icons.sentiment_very_satisfied_rounded,
    'wow': Icons.sentiment_neutral_rounded,
    '😮': Icons.sentiment_neutral_rounded,
    'cry': Icons.sentiment_very_dissatisfied_rounded,
    '😢': Icons.sentiment_very_dissatisfied_rounded,
    'angry': Icons.mood_bad_rounded,
    '😡': Icons.mood_bad_rounded,
    'thumb_up': Icons.thumb_up_rounded,
    '👍': Icons.thumb_up_rounded,
    'thumb_down': Icons.thumb_down_rounded,
    '👎': Icons.thumb_down_rounded,
    'fire': Icons.local_fire_department_rounded,
    '🔥': Icons.local_fire_department_rounded,
    'clap': Icons.sign_language_rounded,
    '👏': Icons.sign_language_rounded,
  };

  static const Map<String, Color> _colors = {
    'favorite': Colors.redAccent,
    '❤️': Colors.redAccent,
    'laugh': Colors.amber,
    '😂': Colors.amber,
    'wow': Colors.orangeAccent,
    '😮': Colors.orangeAccent,
    'cry': Colors.blueAccent,
    '😢': Colors.blueAccent,
    'angry': Colors.deepOrange,
    '😡': Colors.deepOrange,
    'thumb_up': Colors.yellow,
    '👍': Colors.yellow,
    'thumb_down': Colors.grey,
    '👎': Colors.grey,
    'fire': Colors.deepOrangeAccent,
    '🔥': Colors.deepOrangeAccent,
    'clap': Colors.amberAccent,
    '👏': Colors.amberAccent,
  };

  static Icon getIcon(String key, {double size = 14}) {
    return Icon(
      _icons[key] ?? Icons.star_rounded,
      color: _colors[key] ?? Colors.amber,
      size: size,
    );
  }
}
