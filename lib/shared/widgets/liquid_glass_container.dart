import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Liquid Glassmorphism™ — Proposal #2
/// Reactive frosted glass that warps and ripples based on scroll velocity.
/// When the user scrolls fast, the glass "melts" — blur decreases, the
/// surface distorts with a sine-wave displacement, and a subtle ripple
/// travels across the surface. At rest, it resolidifies into crisp glass.

class LiquidGlassContainer extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final double baseBlur;
  final double maxBlur;
  final Color glassColor;
  final double borderRadius;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    required this.scrollController,
    this.baseBlur = 20.0,
    this.maxBlur = 30.0,
    this.glassColor = const Color(0xE6060D1A),
    this.borderRadius = 0,
  });

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  double _scrollVelocity = 0.0;
  double _currentBlur = 20.0;
  double _warpPhase = 0.0;

  @override
  void initState() {
    super.initState();
    _currentBlur = widget.baseBlur;

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _rippleController.addListener(() {
      if (mounted) {
        setState(() {
          _warpPhase = _rippleController.value * pi * 2;
          // Smoothly decay scroll velocity back to 0
          _scrollVelocity *= 0.95;
          // Lerp blur towards target
          final targetBlur = _scrollVelocity.abs() > 50
              ? widget.baseBlur * 0.3 // Less blur when scrolling fast
              : widget.baseBlur;
          _currentBlur += (targetBlur - _currentBlur) * 0.1;
        });
      }
    });

    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (widget.scrollController.hasClients) {
      final velocity = widget.scrollController.position.activity?.velocity ?? 0;
      _scrollVelocity = velocity.clamp(-500.0, 500.0);
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warpIntensity = (_scrollVelocity.abs() / 500).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          // Blurred backdrop with dynamic blur
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: _currentBlur,
              sigmaY: _currentBlur,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: widget.glassColor,
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
            ),
          ),

          // Liquid warp overlay (only visible during scroll)
          if (warpIntensity > 0.05)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LiquidWarpPainter(
                    phase: _warpPhase,
                    intensity: warpIntensity,
                  ),
                ),
              ),
            ),

          // Content
          widget.child,
        ],
      ),
    );
  }
}

class _LiquidWarpPainter extends CustomPainter {
  final double phase;
  final double intensity;

  _LiquidWarpPainter({required this.phase, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw horizontal wave distortion lines
    final lineCount = 8;
    for (int i = 0; i < lineCount; i++) {
      final y = (i / lineCount) * size.height;
      final path = Path();
      path.moveTo(0, y);

      for (double x = 0; x <= size.width; x += 4) {
        final wave = sin(x * 0.02 + phase + i * 0.5) * 3 * intensity;
        path.lineTo(x, y + wave);
      }

      paint.color = Colors.white.withOpacity(0.04 * intensity);
      canvas.drawPath(path, paint);
    }

    // Shimmer highlight
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.03 * intensity),
          Colors.white.withOpacity(0),
        ],
        stops: [
          (phase / (pi * 2)).clamp(0.0, 0.4),
          ((phase / (pi * 2)) + 0.1).clamp(0.0, 0.6),
          ((phase / (pi * 2)) + 0.2).clamp(0.0, 1.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      shimmerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidWarpPainter oldDelegate) =>
      phase != oldDelegate.phase || intensity != oldDelegate.intensity;
}
