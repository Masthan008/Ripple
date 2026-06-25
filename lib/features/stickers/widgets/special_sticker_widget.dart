import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class SpecialStickerWidget extends StatefulWidget {
  final String emoji;
  final double size;

  const SpecialStickerWidget({
    super.key,
    required this.emoji,
    this.size = 72,
  });

  @override
  State<SpecialStickerWidget> createState() => _SpecialStickerWidgetState();
}

class _SpecialStickerWidgetState extends State<SpecialStickerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  final List<_BubbleParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    // 360 degree rotation loop for the glow backplate
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Initialize 6 bubble particles
    for (int i = 0; i < 6; i++) {
      _particles.add(_BubbleParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.005 + _random.nextDouble() * 0.008,
        radius: 2.0 + _random.nextDouble() * 4.0,
        opacity: 0.1 + _random.nextDouble() * 0.3,
      ));
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _updateParticles() {
    for (final p in _particles) {
      p.y -= p.speed;
      if (p.y < -0.1) {
        p.y = 1.1;
        p.x = _random.nextDouble();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        _updateParticles();

        return SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Shifting neon glow backdrop
              Transform.rotate(
                angle: _glowController.value * 2 * math.pi,
                child: Container(
                  width: widget.size * 1.2,
                  height: widget.size * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        AppColors.aquaCore.withOpacity(0.0),
                        AppColors.aquaCore.withOpacity(0.4),
                        AppColors.warningAmber.withOpacity(0.3),
                        Colors.purpleAccent.withOpacity(0.4),
                        AppColors.aquaCore.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // 2. Custom Painter for floating fluid bubbles
              CustomPaint(
                size: Size(widget.size * 1.3, widget.size * 1.3),
                painter: _BubblePainter(particles: _particles),
              ),

              // 3. Frosted glass panel with neon border
              Container(
                width: widget.size * 1.1,
                height: widget.size * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: AppColors.aquaCore.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.aquaCore.withOpacity(0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                      CurvedAnimation(
                        parent: _glowController,
                        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
                      ),
                    ),
                    child: Text(
                      widget.emoji,
                      style: TextStyle(fontSize: widget.size * 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BubbleParticle {
  double x;
  double y;
  final double speed;
  final double radius;
  final double opacity;

  _BubbleParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
  });
}

class _BubblePainter extends CustomPainter {
  final List<_BubbleParticle> particles;

  _BubblePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = AppColors.aquaCore.withOpacity(p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
