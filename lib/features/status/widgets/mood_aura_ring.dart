import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mood_config.dart';

/// Animated colored aura ring around profile avatars based on user's current mood.
/// Uses SweepGradient with mood-specific colors and animations:
///   - happy/vibing: gentle pulse
///   - focused: steady glow
///   - busy: fast pulse
///   - gaming: RGB cycle rotation
class MoodAuraRing extends StatefulWidget {
  final String mood;
  final double radius;
  final Widget child;

  const MoodAuraRing({
    super.key,
    required this.mood,
    this.radius = 28,
    required this.child,
  });

  @override
  State<MoodAuraRing> createState() => _MoodAuraRingState();
}

class _MoodAuraRingState extends State<MoodAuraRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getDuration(),
    )..repeat(reverse: widget.mood != 'gaming');
  }

  @override
  void didUpdateWidget(covariant MoodAuraRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _controller.duration = _getDuration();
      _controller.repeat(reverse: widget.mood != 'gaming');
    }
  }

  Duration _getDuration() {
    switch (widget.mood) {
      case 'busy':
        return const Duration(milliseconds: 600);
      case 'gaming':
        return const Duration(seconds: 2);
      case 'focused':
        return const Duration(milliseconds: 1500);
      default:
        return const Duration(seconds: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MoodConfig.getColors(widget.mood);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: widget.mood == 'gaming'
                  ? const [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ]
                  : [
                      colors[0]
                          .withValues(alpha: 0.3 + 0.7 * _controller.value),
                      colors[1],
                      colors[0]
                          .withValues(alpha: 0.3 + 0.7 * _controller.value),
                    ],
              transform: widget.mood == 'gaming'
                  ? GradientRotation(_controller.value * 2 * math.pi)
                  : null,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: 0.3 * _controller.value),
                blurRadius: 8 + 4 * _controller.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF060D1A),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
