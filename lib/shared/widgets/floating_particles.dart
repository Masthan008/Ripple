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
        size: 3 + _random.nextDouble() * 5,
        delay: _random.nextDouble() * 3,
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
              // Float from bottom to top
              final yPosition = 1.0 - progress;
              // Opacity: fade in → stay → fade out
              double opacity;
              if (progress < 0.1) {
                opacity = progress / 0.1;
              } else if (progress > 0.9) {
                opacity = (1.0 - progress) / 0.1;
              } else {
                opacity = 1.0;
              }
              opacity *= 0.6;

              return Positioned(
                left: particle.xPosition *
                    (MediaQuery.of(context).size.width - particle.size),
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

  _ParticleData({
    required this.controller,
    required this.xPosition,
    required this.size,
    required this.delay,
  });
}
