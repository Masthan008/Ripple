import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Bioluminescent glow effect for active chats and new messages — theme-aware
class BioluminescentGlow extends ConsumerStatefulWidget {
  final Widget child;
  final bool isActive;
  final bool hasNewMessages;
  final double glowIntensity;

  const BioluminescentGlow({
    super.key,
    required this.child,
    this.isActive = false,
    this.hasNewMessages = false,
    this.glowIntensity = 1.0,
  });

  @override
  ConsumerState<BioluminescentGlow> createState() => _BioluminescentGlowState();
}

class _BioluminescentGlowState extends ConsumerState<BioluminescentGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isActive || widget.hasNewMessages) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(BioluminescentGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive || widget.hasNewMessages) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && !widget.hasNewMessages) {
      return widget.child;
    }

    final theme = ref.watch(rippleThemeProvider);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseValue = math.sin(_controller.value * 2 * math.pi) * 0.5 + 0.5;
        final glowOpacity = 0.3 + (pulseValue * 0.4 * widget.glowIntensity);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              // Inner glow
              BoxShadow(
                color: theme.colors.primary.withOpacity(glowOpacity * 0.5),
                blurRadius: 20 * widget.glowIntensity,
                spreadRadius: -5,
              ),
              // Outer glow
              BoxShadow(
                color: theme.colors.secondary.withOpacity(glowOpacity * 0.3),
                blurRadius: 40 * widget.glowIntensity,
                spreadRadius: 5,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Animated pulse ring for new message indicators — theme-aware
class PulseRing extends ConsumerStatefulWidget {
  final double size;
  final Color? color;
  final int ringCount;

  const PulseRing({
    super.key,
    this.size = 20,
    this.color,
    this.ringCount = 3,
  });

  @override
  ConsumerState<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends ConsumerState<PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final ringColor = widget.color ?? theme.colors.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(widget.ringCount, (index) {
              final delay = index / widget.ringCount;
              final animationValue =
                  ((_controller.value + delay) % 1.0);
              final scale = 0.5 + (animationValue * 0.5);
              final opacity = 1 - animationValue;

              return Container(
                width: widget.size * scale,
                height: widget.size * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor.withOpacity(opacity * 0.6),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
