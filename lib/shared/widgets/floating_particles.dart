import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Animated floating water particles in background
/// From PRD §5.5 — small glowing circles float upward
class FloatingParticles extends StatefulWidget {
  final int particleCount;
  final Color color;

  const FloatingParticles({
    super.key,
    this.particleCount = 7,
    this.color = AppColors.aquaCore,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

class _FloatingParticlesState extends State<FloatingParticles>
    with TickerProviderStateMixin {
  late final List<_ParticleData> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 8000 + _random.nextInt(4000), // 8-12s
        ),
      );

      final data = _ParticleData(
        controller: controller,
        xPosition: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 6, // More varied sizes
        delay: _random.nextDouble() * 5, // More spread out
        speed: 0.8 + _random.nextDouble() * 0.7, // Varied speeds
      );

      // Start with staggered delays
      Future.delayed(Duration(milliseconds: (data.delay * 1000).toInt()), () {
        if (mounted) {
          controller.repeat();
        }
      });

      return data;
    });
  }

  @override
  void dispose() {
    for (final p in _particles) {
      p.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: _particles.map((particle) {
          return AnimatedBuilder(
            animation: particle.controller,
            builder: (_, __) {
              final progress = particle.controller.value;
              // Float from bottom to top with slight horizontal drift
              final yPosition = 1.1 - (progress * 1.2);
              final drift = sin(progress * pi * 2) * 0.02;
              final xPos = (particle.xPosition + drift).clamp(0.0, 1.0);

              // Opacity: fade in → stay → fade out
              double opacity;
              if (progress < 0.15) {
                opacity = progress / 0.15;
              } else if (progress > 0.85) {
                opacity = (1.0 - progress) / 0.15;
              } else {
                opacity = 1.0;
              }
              opacity *= 0.4; // Softer particles

              return Positioned(
                left: xPos * MediaQuery.of(context).size.width,
                top: yPosition * MediaQuery.of(context).size.height,
                child: Container(
                  width: particle.size,
                  height: particle.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.color.withValues(alpha: opacity),
                        widget.color.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: opacity * 0.5),
                        blurRadius: particle.size * 2,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}

class _ParticleData {
  final AnimationController controller;
  final double xPosition;
  final double size;
  final double delay;
  final double speed;

  _ParticleData({
    required this.controller,
    required this.xPosition,
    required this.size,
    required this.delay,
    required this.speed,
  });
}
