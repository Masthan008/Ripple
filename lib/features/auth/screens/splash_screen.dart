import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/floating_particles.dart';

/// Splash Screen — Premium Liquid Glass entrance
/// Multi-stage animation: Ripple rings → Logo scale → Text reveal → Wave loader
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Stage 1: Ripple rings expand outward
  late AnimationController _rippleController;
  // Stage 2: Logo scales in with elastic bounce  
  late AnimationController _logoController;
  // Stage 3: Text fades up
  late AnimationController _textController;
  // Stage 4: Wave loading indicator
  late AnimationController _waveController;
  // Continuous glow breathing
  late AnimationController _glowController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    // ── Stage 1: Ripple rings (0–1200ms, repeats) ──
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // ── Stage 2: Logo entrance (200ms delay, 800ms duration) ──
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // ── Stage 3: Text entrance (staggered) ──
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── Stage 4: Wave loader (continuous) ──
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Glow breathing (continuous)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000), // Slower, more liquid drift
    )..repeat(reverse: false); // Loop continuously for smooth drift

    // Orchestrate the animation sequence
    _startAnimationSequence();

    // Auto-navigate after splash checks are complete
    _checkAuthAndNavigate();
  }

  void _startAnimationSequence() async {
    // Delay before logo
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _logoController.forward();

    // Delay before text
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _textController.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    final minTimeFuture = Future.delayed(const Duration(milliseconds: 2200));
    String targetPath = '/login';
    
    try {
      final user = FirebaseService.auth.currentUser;
      if (user != null) {
        final doc = await FirebaseService.usersCollection
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final hasRegFlag =
              data?.containsKey('isRegistrationComplete') ?? false;

          bool isComplete;
          if (hasRegFlag) {
            isComplete = data!['isRegistrationComplete'] as bool? ?? false;
          } else {
            final name = data?['name'] as String? ?? '';
            isComplete = name.isNotEmpty;
          }

          if (isComplete) {
            targetPath = '/home';
          } else {
            targetPath = '/register?uid=${user.uid}'
                '&name=${Uri.encodeComponent(data?['name'] ?? user.displayName ?? '')}'
                '&email=${Uri.encodeComponent(user.email ?? '')}'
                '&photoUrl=${Uri.encodeComponent(data?['photoUrl'] ?? user.photoURL ?? '')}'
                '&isGoogleSignIn=true';
          }
        }
      }
    } catch (_) {
      targetPath = '/login';
    }

    // Wait for the minimum splash duration to play entrance animations
    await minTimeFuture;
    if (mounted) {
      context.go(targetPath);
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _waveController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colors.background,
      body: Stack(
        children: [
          // Animated drifting liquid background orbs
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _LiquidOrbsPainter(
                  progress: _glowController.value,
                  primaryColor: theme.colors.primary,
                  secondaryColor: theme.colors.secondary,
                ),
              );
            },
          ),

          // Floating particles background
          const FloatingParticles(particleCount: 8),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Ripple Rings + Logo ──
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Expanding ripple rings
                      AnimatedBuilder(
                        animation: _rippleController,
                        builder: (_, __) {
                          return CustomPaint(
                            size: const Size(160, 160),
                            painter: _RippleRingPainter(
                              progress: _rippleController.value,
                              color: theme.colors.primary,
                              ringCount: 3,
                            ),
                          );
                        },
                      ),
                      // Logo with elastic scale
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (_, __) {
                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colors.primary.withOpacity(0.4),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/ripple_logo.png',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── App Name with gradient shimmer ──
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, __) {
                    return SlideTransition(
                      position: _titleSlide,
                      child: Opacity(
                        opacity: _titleOpacity.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              theme.gradients.primary.createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                          child: Text(
                            'Ripple',
                            style: AppTextStyles.display.copyWith(
                              color: Colors.white,
                              fontSize: 46,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 10),

                // ── Tagline ──
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, __) {
                    return SlideTransition(
                      position: _taglineSlide,
                      child: Opacity(
                        opacity: _taglineOpacity.value,
                        child: Text(
                          'Connect in liquid-clear conversations',
                          style: AppTextStyles.subtitle.copyWith(
                            color: theme.colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // ── Custom Wave Loading Indicator ──
                AnimatedBuilder(
                  animation: Listenable.merge([_textController, _waveController]),
                  builder: (_, __) {
                    return Opacity(
                      opacity: _loaderOpacity.value,
                      child: SizedBox(
                        width: 48,
                        height: 12,
                        child: CustomPaint(
                          painter: _WaveLoaderPainter(
                            progress: _waveController.value,
                            color: theme.colors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints expanding, fading concentric rings around the logo
class _RippleRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int ringCount;

  _RippleRingPainter({
    required this.progress,
    required this.color,
    this.ringCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < ringCount; i++) {
      final phase = (progress + i / ringCount) % 1.0;
      final radius = 30 + (maxRadius - 30) * phase;
      final opacity = (1.0 - phase) * 0.4;

      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1.0 - phase) + 0.5;

        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RippleRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Paints a small sine-wave loading indicator
class _WaveLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveLoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw 3 bouncing dots
    for (int i = 0; i < 3; i++) {
      final phase = (progress * 2 * math.pi) + (i * math.pi * 0.6);
      final bounce = math.sin(phase).abs();
      final x = size.width * (0.2 + i * 0.3);
      final y = size.height / 2 - (bounce * 4);
      final dotSize = 3.0 + bounce * 1.5;

      canvas.drawCircle(
        Offset(x, y),
        dotSize,
        paint..color = color.withOpacity(0.4 + bounce * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Paints drifting, organic liquid color blobs for background
class _LiquidOrbsPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _LiquidOrbsPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Orb 1: Primary color drifting top-left
    final x1 = width * (0.2 + 0.15 * math.sin(progress * 2 * math.pi));
    final y1 = height * (0.2 + 0.12 * math.cos(progress * 2 * math.pi));
    final r1 = width * 0.55;

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.12),
          primaryColor.withOpacity(0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: r1));
    canvas.drawCircle(Offset(x1, y1), r1, paint1);

    // Orb 2: Secondary color drifting bottom-right
    final x2 = width * (0.8 + 0.15 * math.cos(progress * 2 * math.pi + 1.0));
    final y2 = height * (0.8 + 0.12 * math.sin(progress * 2 * math.pi + 1.0));
    final r2 = width * 0.65;

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryColor.withOpacity(0.09),
          secondaryColor.withOpacity(0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: r2));
    canvas.drawCircle(Offset(x2, y2), r2, paint2);

    // Orb 3: Cyan/Aqua light beam drifting center-left
    final x3 = width * (0.4 + 0.2 * math.sin(progress * 2 * math.pi + 2.0));
    final y3 = height * (0.5 + 0.15 * math.cos(progress * 2 * math.pi + 2.0));
    final r3 = width * 0.48;

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(0.06),
          const Color(0xFF00E5FF).withOpacity(0.01),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x3, y3), radius: r3));
    canvas.drawCircle(Offset(x3, y3), r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _LiquidOrbsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
