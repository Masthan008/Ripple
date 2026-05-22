import 'dart:math';
import 'package:flutter/material.dart';

/// Holographic Glitch Transition™ — Proposal #1
/// Instead of standard sliding transitions, the new screen materializes
/// with chromatic aberration (RGB channel split), digital stutter, and
/// a sharp snap-to-focus effect. Cyberpunk-grade navigation.

class HolographicGlitchTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const HolographicGlitchTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Phase 1 (0.0–0.3): Chromatic aberration + glitch lines
        // Phase 2 (0.3–0.7): Rapid stutter + scale shake
        // Phase 3 (0.7–1.0): Snap into sharp focus
        final t = animation.value;

        // Chromatic aberration offset (decreases as animation progresses)
        final chromaticOffset = (1.0 - t) * 6.0;

        // Glitch intensity (strongest at start, fades)
        final glitchIntensity = (1.0 - t).clamp(0.0, 1.0);

        // Scale: starts slightly larger, overshoots, settles
        final scale = 1.0 + (sin(t * pi * 4) * 0.02 * glitchIntensity);

        // Opacity with fast ramp
        final opacity = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Stack(
              children: [
                // Red channel (shifted left-up)
                if (chromaticOffset > 0.5)
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(-chromaticOffset, -chromaticOffset * 0.5),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x30FF0040),
                          BlendMode.srcATop,
                        ),
                        child: child!,
                      ),
                    ),
                  ),

                // Blue channel (shifted right-down)
                if (chromaticOffset > 0.5)
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(chromaticOffset, chromaticOffset * 0.5),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x3000D4FF),
                          BlendMode.srcATop,
                        ),
                        child: child!,
                      ),
                    ),
                  ),

                // Main child (always on top)
                child!,

                // Scanline / glitch overlay
                if (glitchIntensity > 0.2)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _GlitchOverlayPainter(
                          intensity: glitchIntensity,
                          seed: (t * 1000).toInt(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      child: child,
    );
  }

  /// Build a CustomTransitionPage that uses the holographic glitch effect
  static Widget transitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return HolographicGlitchTransition(
      animation: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutExpo,
      ),
      child: child,
    );
  }
}

class _GlitchOverlayPainter extends CustomPainter {
  final double intensity;
  final int seed;

  _GlitchOverlayPainter({required this.intensity, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint();

    // Horizontal glitch bars
    final barCount = (intensity * 8).round();
    for (int i = 0; i < barCount; i++) {
      final y = random.nextDouble() * size.height;
      final barHeight = 1.0 + random.nextDouble() * 3.0;
      final offset = (random.nextDouble() - 0.5) * 20 * intensity;

      paint.color = Color.fromRGBO(
        random.nextBool() ? 0 : 255,
        random.nextBool() ? 255 : 0,
        random.nextBool() ? 255 : 0,
        0.1 * intensity,
      );

      canvas.save();
      canvas.translate(offset, 0);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, barHeight),
        paint,
      );
      canvas.restore();
    }

    // Thin scanlines
    paint.color = Colors.white.withOpacity(0.03 * intensity);
    for (double y = 0; y < size.height; y += 2) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlitchOverlayPainter oldDelegate) =>
      intensity != oldDelegate.intensity || seed != oldDelegate.seed;
}
