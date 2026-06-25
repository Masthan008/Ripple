import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/theme_models.dart';

/// Interactive physics-based Water Droplet Background
/// Simulates physical dew condensation, gravity slide, merging, and user touch ripples.
class WaterDropletBackground extends StatefulWidget {
  final Widget child;
  final int maxDroplets;
  final bool enableTouchEffect;
  final RippleTheme? theme;

  const WaterDropletBackground({
    super.key,
    required this.child,
    this.maxDroplets = 24,
    this.enableTouchEffect = true,
    this.theme,
  });

  @override
  State<WaterDropletBackground> createState() => _WaterDropletBackgroundState();
}

class _WaterDropletBackgroundState extends State<WaterDropletBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Droplet> _droplets = [];
  final List<_Ripple> _ripples = [];
  final Random _random = Random();
  Size _screenSize = Size.zero;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // 60 FPS animation ticker
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_initialized || _screenSize == Size.zero) return;

    setState(() {
      // 1. Update physical ripples
      for (int i = _ripples.length - 1; i >= 0; i--) {
        final ripple = _ripples[i];
        ripple.radius += 4.5;
        ripple.opacity -= 0.035;
        if (ripple.opacity <= 0) {
          _ripples.removeAt(i);
        }
      }

      // 2. Physics & Gravity Simulation for droplets
      for (int i = 0; i < _droplets.length; i++) {
        final d = _droplets[i];

        if (d.isSliding) {
          // Slide downwards with variable speeds
          d.y += d.speed;
          
          // Wobble horizontally to simulate surface friction
          d.wobblePhase += d.wobbleSpeed;
          d.x += sin(d.wobblePhase) * 0.25;

          // Drag trail effect
          if (d.y - d.lastTrailY > d.radius * 2.5) {
            d.trailPoints.add(Offset(d.x, d.y));
            d.lastTrailY = d.y;
            if (d.trailPoints.length > 5) {
              d.trailPoints.removeAt(0);
            }
          }

          // Merge checks with static or other sliding drops
          for (int j = 0; j < _droplets.length; j++) {
            if (i == j) continue;
            final other = _droplets[j];

            final dx = d.x - other.x;
            final dy = d.y - other.y;
            final distance = sqrt(dx * dx + dy * dy);

            // Collide and merge
            if (distance < (d.radius + other.radius) * 0.85) {
              if (d.radius >= other.radius) {
                // Absorb smaller droplet
                d.radius = sqrt(d.radius * d.radius + other.radius * other.radius);
                d.radius = d.radius.clamp(4.0, 16.0); // Clamp to prevent giant drops
                d.speed = (d.speed + 0.3).clamp(1.5, 4.0); // Larger drops run faster
                _resetDroplet(other, randomY: true);
              }
            }
          }
        } else {
          // Small chance for a static droplet to begin sliding (condensation threshold)
          if (_random.nextDouble() < 0.0008 * (d.radius / 5)) {
            d.isSliding = true;
            d.speed = 1.0 + _random.nextDouble() * 1.5;
          }
        }

        // Reset droplet if it runs off screen bottom
        if (d.y > _screenSize.height + 20) {
          _resetDroplet(d);
        }
      }
    });
  }

  void _initializeDroplets(Size size) {
    _screenSize = size;
    _droplets.clear();
    for (int i = 0; i < widget.maxDroplets; i++) {
      final d = _Droplet(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        radius: 3.5 + _random.nextDouble() * 5.5,
        isSliding: _random.nextDouble() < 0.15, // 15% start sliding immediately
        speed: 1.0 + _random.nextDouble() * 2.0,
        wobbleSpeed: 0.05 + _random.nextDouble() * 0.1,
        wobblePhase: _random.nextDouble() * pi * 2,
      );
      d.lastTrailY = d.y;
      _droplets.add(d);
    }
    _initialized = true;
  }

  void _resetDroplet(_Droplet d, {bool randomY = false}) {
    d.x = _random.nextDouble() * _screenSize.width;
    d.y = randomY ? (_random.nextDouble() * _screenSize.height) : -20.0;
    d.radius = 3.0 + _random.nextDouble() * 5.0;
    d.isSliding = false;
    d.speed = 1.0 + _random.nextDouble() * 1.5;
    d.wobblePhase = _random.nextDouble() * pi * 2;
    d.trailPoints.clear();
    d.lastTrailY = d.y;
  }

  void _handleTap(TapUpDetails details) {
    if (!widget.enableTouchEffect) return;

    final tapPos = details.localPosition;

    setState(() {
      // 1. Spawn a ripple
      _ripples.add(_Ripple(
        x: tapPos.dx,
        y: tapPos.dy,
        radius: 5.0,
        opacity: 0.8,
      ));

      // 2. Add a new water droplet at tapped coordinate
      final newDrop = _Droplet(
        x: tapPos.dx,
        y: tapPos.dy,
        radius: 5.5 + _random.nextDouble() * 4.5,
        isSliding: true, // Touched drops run down
        speed: 2.0 + _random.nextDouble() * 1.5,
        wobbleSpeed: 0.1,
        wobblePhase: _random.nextDouble() * pi,
      );
      newDrop.lastTrailY = tapPos.dy;

      // Clean oldest if exceeding maximum size limit
      if (_droplets.length >= widget.maxDroplets + 6) {
        _droplets.removeAt(0);
      }
      _droplets.add(newDrop);

      // 3. Disturb nearby droplets
      for (final d in _droplets) {
        final dx = d.x - tapPos.dx;
        final dy = d.y - tapPos.dy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < 120.0 && !d.isSliding) {
          d.isSliding = true;
          d.speed = 1.5 + _random.nextDouble() * 1.0;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (!_initialized || _screenSize != size) {
          _initializeDroplets(size);
        }

        return GestureDetector(
          onTapUp: _handleTap,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // Liquid gloss backdrop reflection
              Container(
                decoration: BoxDecoration(
                  color: widget.theme?.colors.background ?? Colors.white,
                  gradient: widget.theme != null
                      ? LinearGradient(
                          colors: [
                            widget.theme!.colors.background,
                            widget.theme!.colors.background.withOpacity(0.97),
                            Color.lerp(widget.theme!.colors.background, const Color(0xFFD3E5F8), 0.12)!,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFF9FAFB),
                            Color(0xFFF3F4F6),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                ),
              ),
              // Spotlights (White Light theme glow spots)
              Positioned(
                top: 100,
                left: 50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.theme != null
                            ? widget.theme!.colors.primary.withOpacity(0.08)
                            : Colors.white.withOpacity(0.95),
                        blurRadius: 100,
                        spreadRadius: 20,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.90),
                        blurRadius: 80,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 150,
                right: 30,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.theme != null
                            ? widget.theme!.colors.secondary.withOpacity(0.06)
                            : Colors.white.withOpacity(0.90),
                        blurRadius: 120,
                        spreadRadius: 30,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.85),
                        blurRadius: 100,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                ),
              ),

              // Physical Water Droplet Custom Paint
              CustomPaint(
                painter: _WaterDropletPainter(
                  droplets: _droplets,
                  ripples: _ripples,
                  theme: widget.theme,
                ),
                size: Size.infinite,
              ),

              // Foreground Content
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// Simulated physical parameters for each individual water drop
class _Droplet {
  double x;
  double y;
  double radius;
  bool isSliding;
  double speed;
  double wobbleSpeed;
  double wobblePhase;
  double lastTrailY = 0.0;
  final List<Offset> trailPoints = [];

  _Droplet({
    required this.x,
    required this.y,
    required this.radius,
    required this.isSliding,
    required this.speed,
    required this.wobbleSpeed,
    required this.wobblePhase,
  });
}

/// Simulated water ripple effect created upon user interaction
class _Ripple {
  final double x;
  final double y;
  double radius;
  double opacity;

  _Ripple({
    required this.x,
    required this.y,
    required this.radius,
    required this.opacity,
  });
}

/// Custom Painter that renders high-fidelity glass water droplets and expanding rings
class _WaterDropletPainter extends CustomPainter {
  final List<_Droplet> droplets;
  final List<_Ripple> ripples;
  final RippleTheme? theme;

  _WaterDropletPainter({
    required this.droplets,
    required this.ripples,
    this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isLightTheme = theme != null && !theme!.isDark;

    // 1. Draw ripples first (background layer)
    for (final ripple in ripples) {
      final ripplePaint = Paint()
        ..color = (theme?.colors.primary ?? const Color(0xFF007AFF)).withOpacity(ripple.opacity * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(
        Offset(ripple.x, ripple.y),
        ripple.radius,
        ripplePaint,
      );

      final outerRipplePaint = Paint()
        ..color = (theme?.colors.secondary ?? const Color(0xFF5856D6)).withOpacity(ripple.opacity * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(
        Offset(ripple.x, ripple.y),
        ripple.radius * 1.5,
        outerRipplePaint,
      );
    }

    // 2. Draw water droplets
    for (final d in droplets) {
      final center = Offset(d.x, d.y);

      // A. Draw wet sliding trail behind droplet (if any)
      if (d.trailPoints.isNotEmpty) {
        for (int i = 0; i < d.trailPoints.length; i++) {
          final pt = d.trailPoints[i];
          final progress = i / d.trailPoints.length;
          final trailPaint = Paint()
            ..color = Colors.white.withOpacity(0.35 * progress)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pt, d.radius * 0.6 * progress, trailPaint);

          final trailBorder = Paint()
            ..color = const Color(0x15000000).withOpacity(0.08 * progress)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;
          canvas.drawCircle(pt, d.radius * 0.6 * progress, trailBorder);
        }
      }

      // B. Drop Shadow (Physical offset volume)
      final shadowPaint = Paint()
        ..color = isLightTheme 
            ? const Color(0x35000000) // Stronger shadow for light theme
            : const Color(0x18000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isLightTheme ? 3.0 : 2.5);
      canvas.drawCircle(
        center + Offset(isLightTheme ? 1.2 : 1.0, isLightTheme ? 2.2 : 1.8),
        d.radius,
        shadowPaint,
      );

      // C. Base Droplet Body (Simulating translucent lens)
      final bodyGradient = RadialGradient(
        center: const Alignment(-0.25, -0.25),
        radius: 0.85,
        colors: [
          Colors.white.withOpacity(isLightTheme ? 0.32 : 0.45), // Inner light center
          isLightTheme
              ? const Color(0xFFCBE2FA).withOpacity(0.12)
              : Colors.blueGrey.withOpacity(0.03),
          isLightTheme
              ? const Color(0x28000000) // Darker refraction edge on light backgrounds
              : const Color(0x1B000000), // Darker edge refraction
        ],
        stops: const [0.0, 0.7, 1.0],
      );

      final bodyPaint = Paint()
        ..shader = bodyGradient.createShader(
          Rect.fromCircle(center: center, radius: d.radius),
        );
      canvas.drawCircle(center, d.radius, bodyPaint);

      // D. Outer Refraction Edge (Adds sharp glass definition)
      final borderPaint = Paint()
        ..color = isLightTheme 
            ? const Color(0x44000000) // Distinct dark edge border for visibility
            : Colors.white.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLightTheme ? 0.75 : 0.65;
      canvas.drawCircle(center, d.radius, borderPaint);

      final darkEdgePaint = Paint()
        ..color = isLightTheme
            ? const Color(0x26000000)
            : const Color(0x1E000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35;
      canvas.drawCircle(center, d.radius - 0.5, darkEdgePaint);

      // E. Specular Glare (Highlight Reflection)
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.88);
      
      // Top-Left glare circle
      canvas.drawCircle(
        center + Offset(-d.radius * 0.35, -d.radius * 0.35),
        d.radius * 0.22,
        highlightPaint,
      );

      // Subtle opposite bounce reflection (Bottom-Right crescent glow)
      final secondaryHighlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.28);
      canvas.drawCircle(
        center + Offset(d.radius * 0.28, d.radius * 0.28),
        d.radius * 0.15,
        secondaryHighlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
