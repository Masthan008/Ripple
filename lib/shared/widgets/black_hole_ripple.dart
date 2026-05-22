import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/utils/haptic_feedback.dart';

/// Magnetic Black Hole Ripple™ — Proposal #7
/// When long-pressing a message, a gravitational distortion field
/// emanates from the touch point, pulling nearby content inward
/// before releasing with a heavy haptic thud.

class BlackHoleRippleOverlay extends StatefulWidget {
  final Widget child;

  const BlackHoleRippleOverlay({super.key, required this.child});

  @override
  State<BlackHoleRippleOverlay> createState() => BlackHoleRippleOverlayState();
}

class BlackHoleRippleOverlayState extends State<BlackHoleRippleOverlay>
    with SingleTickerProviderStateMixin {
  Offset? _epicenter;
  late AnimationController _controller;
  late Animation<double> _pullAnimation;
  late Animation<double> _releaseAnimation;
  bool _isActive = false;
  bool _isReleasing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pullAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _releaseAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Call this from message bubble's onLongPressStart
  void triggerBlackHole(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    _epicenter = box.globalToLocal(globalPosition);
    _isActive = true;
    _isReleasing = false;
    _controller.forward(from: 0);
    AppHaptics.heavyTap();
  }

  /// Call this from onLongPressEnd
  void release() {
    _isReleasing = true;
    AppHaptics.heavyTap();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _isActive = false;
          _epicenter = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Black hole distortion overlay
        if (_isActive && _epicenter != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _BlackHolePainter(
                      epicenter: _epicenter!,
                      pullIntensity: _isReleasing
                          ? _pullAnimation.value * (1 - _releaseAnimation.value)
                          : _pullAnimation.value,
                      isReleasing: _isReleasing,
                      releaseProgress: _releaseAnimation.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _BlackHolePainter extends CustomPainter {
  final Offset epicenter;
  final double pullIntensity;
  final bool isReleasing;
  final double releaseProgress;

  _BlackHolePainter({
    required this.epicenter,
    required this.pullIntensity,
    required this.isReleasing,
    required this.releaseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pullIntensity <= 0) return;

    // Dark vortex at epicenter
    final vortexRadius = 40.0 * pullIntensity;
    final vortexPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withOpacity(0.4 * pullIntensity),
          Colors.black.withOpacity(0.1 * pullIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(center: epicenter, radius: vortexRadius * 3),
      );

    canvas.drawCircle(epicenter, vortexRadius * 3, vortexPaint);

    // Gravitational field rings
    for (int i = 1; i <= 4; i++) {
      final ringRadius = vortexRadius + i * 30 * pullIntensity;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF6366F1).withOpacity(
          (0.3 - i * 0.06) * pullIntensity,
        );

      canvas.drawCircle(epicenter, ringRadius, ringPaint);
    }

    // Release shockwave
    if (isReleasing && releaseProgress > 0) {
      final shockRadius = releaseProgress * 200;
      final shockPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF22D3EE).withOpacity(
          0.5 * (1 - releaseProgress),
        );

      canvas.drawCircle(epicenter, shockRadius, shockPaint);

      // Secondary softer ring
      final secondaryPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF6366F1).withOpacity(
          0.3 * (1 - releaseProgress),
        );

      canvas.drawCircle(epicenter, shockRadius * 0.7, secondaryPaint);
    }

    // Particle-like debris around epicenter
    final random = Random(42);
    for (int i = 0; i < 12; i++) {
      final angle = random.nextDouble() * pi * 2;
      final baseDistance = 20 + random.nextDouble() * 60;
      final distance = baseDistance * (isReleasing
          ? 1.0 + releaseProgress * 2
          : 1.0 - pullIntensity * 0.3);

      final px = epicenter.dx + cos(angle) * distance;
      final py = epicenter.dy + sin(angle) * distance;

      final dotPaint = Paint()
        ..color = const Color(0xFF0EA5E9).withOpacity(
          0.4 * pullIntensity * (isReleasing ? 1 - releaseProgress : 1),
        );

      canvas.drawCircle(Offset(px, py), 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlackHolePainter oldDelegate) =>
      pullIntensity != oldDelegate.pullIntensity ||
      releaseProgress != oldDelegate.releaseProgress;
}
