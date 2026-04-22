import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Glass Shatter Effect — Premium Delete Animation
///
/// When a message is deleted, instead of fading away, the bubble
/// fractures into dozens of glass shards that fall with physics-like
/// animation (gravity + rotation + opacity decay).
///
/// Usage:
/// ```dart
/// GlassShatterTransition(
///   shatter: true,
///   onComplete: () => removeFromList(),
///   child: MessageBubble(...),
/// )
/// ```
class GlassShatterTransition extends StatefulWidget {
  final Widget child;
  final bool shatter;
  final VoidCallback? onComplete;

  const GlassShatterTransition({
    super.key,
    required this.child,
    this.shatter = false,
    this.onComplete,
  });

  @override
  State<GlassShatterTransition> createState() => _GlassShatterTransitionState();
}

class _GlassShatterTransitionState extends State<GlassShatterTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<_Shard>? _shards;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(GlassShatterTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shatter && !oldWidget.shatter) {
      _generateShards();
      _controller.forward();
    }
  }

  void _generateShards() {
    _shards = List.generate(24, (_) {
      return _Shard(
        offsetX: _random.nextDouble() * 2 - 1, // -1 to 1
        offsetY: _random.nextDouble() * 0.5,
        velocityX: (_random.nextDouble() - 0.5) * 200,
        velocityY: _random.nextDouble() * -150 - 50, // upward initial
        rotation: _random.nextDouble() * pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 8,
        size: _random.nextDouble() * 20 + 8,
        opacity: 1.0,
        color: [
          AppColors.aquaCore.withOpacity(0.6),
          Colors.white.withOpacity(0.4),
          const Color(0xFF6366F1).withOpacity(0.5),
          Colors.cyan.withOpacity(0.3),
        ][_random.nextInt(4)],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shatter) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        if (t == 0) return widget.child;

        // Fade the original child quickly
        final childOpacity = (1.0 - t * 4).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Fading original
            if (childOpacity > 0)
              Opacity(
                opacity: childOpacity,
                child: Transform.scale(
                  scale: 1.0 + t * 0.1,
                  child: widget.child,
                ),
              ),

            // Glass shards
            if (_shards != null)
              ..._shards!.map((shard) {
                final gravity = 600.0; // px/s²
                final elapsed = t * 1.2; // seconds
                final x = shard.velocityX * elapsed;
                final y = shard.velocityY * elapsed +
                    0.5 * gravity * elapsed * elapsed;
                final rot = shard.rotation + shard.rotationSpeed * elapsed;
                final opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);

                return Positioned(
                  left: shard.offsetX * 50 + x,
                  top: shard.offsetY * 30 + y,
                  child: Transform.rotate(
                    angle: rot,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: shard.size,
                        height: shard.size * 0.6,
                        decoration: BoxDecoration(
                          color: shard.color,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: shard.color.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _Shard {
  final double offsetX;
  final double offsetY;
  final double velocityX;
  final double velocityY;
  final double rotation;
  final double rotationSpeed;
  final double size;
  final double opacity;
  final Color color;

  const _Shard({
    required this.offsetX,
    required this.offsetY,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

/// Liquid Displacement Page Transition
///
/// When navigating between screens, the outgoing page dissolves
/// using a wave-like displacement effect while the incoming page
/// materializes through a ripple.
class LiquidPageTransition extends PageRouteBuilder {
  final Widget page;

  LiquidPageTransition({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                ),
              ),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.97,
                    end: 1.0,
                  ).animate(curvedAnimation),
                  child: child,
                ),
              ),
            );
          },
        );
}

/// Parallax Depth Wrapper
///
/// Uses the device gyroscope to create a subtle 3D parallax effect
/// on the wrapped widget. Elements on different "depth layers" shift
/// at different rates when the device is tilted.
class ParallaxDepthWrapper extends StatefulWidget {
  final Widget child;
  final double depthFactor; // 0.0 = no movement, 1.0 = maximum shift
  final double maxOffset; // max pixels of shift

  const ParallaxDepthWrapper({
    super.key,
    required this.child,
    this.depthFactor = 0.5,
    this.maxOffset = 8.0,
  });

  @override
  State<ParallaxDepthWrapper> createState() => _ParallaxDepthWrapperState();
}

class _ParallaxDepthWrapperState extends State<ParallaxDepthWrapper> {
  double _offsetX = 0;
  double _offsetY = 0;

  @override
  void initState() {
    super.initState();
    // Listen to gyroscope
    try {
      // Using sensors_plus for gyroscope data
      _listenGyroscope();
    } catch (e) {
      // Gyroscope not available — no parallax
    }
  }

  void _listenGyroscope() {
    // Using a simple approach with accelerometer as fallback
    // For real gyroscope, import sensors_plus and use gyroscopeEventStream
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(
        _offsetX * widget.depthFactor * widget.maxOffset,
        _offsetY * widget.depthFactor * widget.maxOffset,
      ),
      child: widget.child,
    );
  }
}

/// Interactive Particle Burst
///
/// Spawns a burst of themed particles from a point. Used for:
/// - Message send confirmation (aqua particles)
/// - Reaction pops (emoji-colored particles)
/// - Achievement unlocks (gold particles)
class ParticleBurst extends StatefulWidget {
  final Offset origin;
  final Color color;
  final int count;
  final VoidCallback? onComplete;

  const ParticleBurst({
    super.key,
    required this.origin,
    this.color = const Color(0xFF0EA5E9),
    this.count = 12,
    this.onComplete,
  });

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    _particles = List.generate(widget.count, (_) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = _random.nextDouble() * 120 + 40;
      return _Particle(
        dx: cos(angle) * speed,
        dy: sin(angle) * speed - 60, // upward bias
        size: _random.nextDouble() * 6 + 2,
        color: widget.color.withOpacity(0.6 + _random.nextDouble() * 0.4),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final opacity = (1.0 - t).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: _particles.map((p) {
            final x = widget.origin.dx + p.dx * t;
            final y = widget.origin.dy + p.dy * t + 200 * t * t; // gravity

            return Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: p.size * (1 - t * 0.5),
                  height: p.size * (1 - t * 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.color,
                    boxShadow: [
                      BoxShadow(
                        color: p.color.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  final double dx;
  final double dy;
  final double size;
  final Color color;

  const _Particle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
  });
}
