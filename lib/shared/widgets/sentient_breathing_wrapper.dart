import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/sentience_engine.dart';

/// Sentient Breathing UI™ — Proposal #3
/// The entire UI subtly "breathes" — scaling and pulsing like a living
/// organism. The breathing rate is driven by the Sentience Engine:
///   • Calm: Slow, deep 4s breaths
///   • Happy: Medium 3s breaths
///   • Excited: Quick 2s breaths
///   • Urgent/Angry: Fast, shallow 1.5s breaths
///   • Sad: Very slow, shallow 5s breaths

class SentientBreathingWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final String chatId;

  const SentientBreathingWrapper({
    super.key,
    required this.child,
    required this.chatId,
  });

  @override
  ConsumerState<SentientBreathingWrapper> createState() =>
      _SentientBreathingWrapperState();
}

class _SentientBreathingWrapperState
    extends ConsumerState<SentientBreathingWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  Duration _currentDuration = const Duration(seconds: 4);
  String _lastMood = 'calm';

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: _currentDuration,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.005).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  Duration _moodToDuration(String mood) {
    switch (mood) {
      case 'calm':
        return const Duration(milliseconds: 4000);
      case 'happy':
        return const Duration(milliseconds: 3000);
      case 'excited':
        return const Duration(milliseconds: 2000);
      case 'urgent':
      case 'angry':
        return const Duration(milliseconds: 1500);
      case 'sad':
        return const Duration(milliseconds: 5000);
      default:
        return const Duration(milliseconds: 4000);
    }
  }

  double _moodToScaleAmplitude(String mood) {
    switch (mood) {
      case 'calm':
        return 1.005;
      case 'happy':
        return 1.008;
      case 'excited':
        return 1.012;
      case 'urgent':
      case 'angry':
        return 1.015;
      case 'sad':
        return 1.003;
      default:
        return 1.005;
    }
  }

  void _updateBreathingForMood(String mood) {
    if (mood == _lastMood) return;
    _lastMood = mood;

    final newDuration = _moodToDuration(mood);
    final newScale = _moodToScaleAmplitude(mood);

    _breathController.duration = newDuration;
    _scaleAnimation = Tween<double>(begin: 1.0, end: newScale).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOutSine),
    );

    // Restart with new duration
    _breathController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final sentience = ref.watch(sentienceProvider(widget.chatId));
    _updateBreathingForMood(sentience.mood);

    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A breathing border wrapper that pulses the border glow
/// in sync with the sentience breathing.
class BreathingBorder extends ConsumerStatefulWidget {
  final Widget child;
  final String chatId;
  final double borderRadius;
  final double borderWidth;

  const BreathingBorder({
    super.key,
    required this.child,
    required this.chatId,
    this.borderRadius = 24,
    this.borderWidth = 1.0,
  });

  @override
  ConsumerState<BreathingBorder> createState() => _BreathingBorderState();
}

class _BreathingBorderState extends ConsumerState<BreathingBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentience = ref.watch(sentienceProvider(widget.chatId));
    final breathValue = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    return AnimatedBuilder(
      animation: breathValue,
      builder: (context, child) {
        final glowOpacity = 0.1 + breathValue.value * 0.25 * sentience.intensity;
        final spreadRadius = breathValue.value * 4 * sentience.intensity;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: sentience.primaryGlow.withOpacity(
                0.2 + breathValue.value * 0.3 * sentience.intensity,
              ),
              width: widget.borderWidth,
            ),
            boxShadow: sentience.intensity > 0
                ? [
                    BoxShadow(
                      color: sentience.primaryGlow.withOpacity(glowOpacity),
                      blurRadius: 12 + breathValue.value * 8,
                      spreadRadius: spreadRadius,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
