import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../models/emotional_signature.dart';

/// Resonance Bubble Animation — Emotional Resonance™
///
/// Wraps a message bubble and applies visual effects based on the
/// sender's emotional signature during composition:
///
/// - **Excited** (🤩): Pulsing glow + scale bounce
/// - **Emphatic** (🔥): Warm red/orange shimmering border
/// - **Thoughtful** (🤔): Slow breathing/fade effect
/// - **Hesitant** (😬): Subtle jitter/shake
/// - **Playful** (😜): Rainbow shimmer border
/// - **Urgent** (⚡): Fast flash + strong haptic
/// - **Neutral** (😌): No extra animation (default)
///
/// Also shows a small emotional tone badge below the bubble.
class ResonanceBubbleAnimation extends StatefulWidget {
  final Widget child;
  final EmotionalSignature? signature;
  final bool isMe;

  const ResonanceBubbleAnimation({
    super.key,
    required this.child,
    this.signature,
    this.isMe = false,
  });

  @override
  State<ResonanceBubbleAnimation> createState() =>
      _ResonanceBubbleAnimationState();
}

class _ResonanceBubbleAnimationState extends State<ResonanceBubbleAnimation>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  bool _hasPlayedHaptic = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _startAnimation();
  }

  void _startAnimation() {
    final sig = widget.signature;
    if (sig == null || sig.tone == EmotionalTone.neutral) return;

    switch (sig.tone) {
      case EmotionalTone.excited:
      case EmotionalTone.urgent:
        _pulseController.repeat(reverse: true);
        break;
      case EmotionalTone.emphatic:
      case EmotionalTone.playful:
        _shimmerController.repeat();
        break;
      case EmotionalTone.thoughtful:
        _pulseController.duration = const Duration(milliseconds: 3000);
        _pulseController.repeat(reverse: true);
        break;
      case EmotionalTone.hesitant:
        _pulseController.duration = const Duration(milliseconds: 500);
        _pulseController.repeat(reverse: true);
        break;
      default:
        break;
    }

    // Play haptic feedback once for non-own messages
    if (!widget.isMe && !_hasPlayedHaptic) {
      _hasPlayedHaptic = true;
      _playEmotionalHaptic(sig.tone, sig.intensity);
    }
  }

  void _playEmotionalHaptic(EmotionalTone tone, double intensity) {
    switch (tone) {
      case EmotionalTone.excited:
        AppHaptics.mediumTap();
        Future.delayed(const Duration(milliseconds: 80), () => AppHaptics.lightTap());
        break;
      case EmotionalTone.emphatic:
      case EmotionalTone.urgent:
        AppHaptics.heavyTap();
        break;
      case EmotionalTone.playful:
        AppHaptics.lightTap();
        Future.delayed(const Duration(milliseconds: 100), () => AppHaptics.lightTap());
        Future.delayed(const Duration(milliseconds: 200), () => AppHaptics.lightTap());
        break;
      case EmotionalTone.hesitant:
        AppHaptics.lightTap();
        break;
      case EmotionalTone.thoughtful:
        // No haptic — thoughtful messages are calm
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sig = widget.signature;

    // No signature or neutral → pass through
    if (sig == null || sig.tone == EmotionalTone.neutral) {
      return widget.child;
    }

    return Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated bubble wrapper
        AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _shimmerController]),
          builder: (context, child) {
            return _buildAnimatedWrapper(sig, child!);
          },
          child: widget.child,
        ),

        // Emotional tone badge
        Padding(
          padding: EdgeInsets.only(
            top: 4,
            left: widget.isMe ? 0 : 12,
            right: widget.isMe ? 12 : 0,
          ),
          child: _EmotionalToneBadge(tone: sig.tone, intensity: sig.intensity),
        ),
      ],
    );
  }

  Widget _buildAnimatedWrapper(EmotionalSignature sig, Widget child) {
    switch (sig.tone) {
      case EmotionalTone.excited:
        // Pulsing scale + glow
        final scale = 1.0 + (_pulseController.value * 0.02 * sig.intensity);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.aquaCore.withOpacity(
                    0.2 * _pulseController.value * sig.intensity,
                  ),
                  blurRadius: 12 * _pulseController.value,
                  spreadRadius: 2 * _pulseController.value,
                ),
              ],
            ),
            child: child,
          ),
        );

      case EmotionalTone.emphatic:
        // Warm shimmering border
        final shimmerPos = _shimmerController.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color.lerp(
                Colors.orange.withOpacity(0.4),
                Colors.red.withOpacity(0.6),
                shimmerPos,
              )!,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.15 * shimmerPos),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );

      case EmotionalTone.urgent:
        // Fast flash effect
        final flash = _pulseController.value > 0.8;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: flash
                ? [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: child,
        );

      case EmotionalTone.playful:
        // Rainbow shimmer
        final hue = (_shimmerController.value * 360) % 360;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: HSLColor.fromAHSL(0.5, hue, 0.7, 0.6).toColor(),
              width: 1.2,
            ),
          ),
          child: child,
        );

      case EmotionalTone.thoughtful:
        // Slow breathing opacity
        final opacity = 0.85 + (_pulseController.value * 0.15);
        return Opacity(
          opacity: opacity,
          child: child,
        );

      case EmotionalTone.hesitant:
        // Subtle jitter
        final offset = sin(_pulseController.value * pi * 2) * 1.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );

      default:
        return child;
    }
  }
}

/// Small badge showing the emotional tone of a message
class _EmotionalToneBadge extends StatelessWidget {
  final EmotionalTone tone;
  final double intensity;

  const _EmotionalToneBadge({
    required this.tone,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getToneColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getToneColor().withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tone.emoji,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 3),
          Text(
            tone.label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: _getToneColor().withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getToneColor() {
    switch (tone) {
      case EmotionalTone.excited:
        return AppColors.aquaCore;
      case EmotionalTone.emphatic:
        return Colors.orange;
      case EmotionalTone.urgent:
        return Colors.yellow;
      case EmotionalTone.playful:
        return Colors.pink;
      case EmotionalTone.thoughtful:
        return Colors.blue;
      case EmotionalTone.hesitant:
        return Colors.grey;
      default:
        return Colors.white;
    }
  }
}
