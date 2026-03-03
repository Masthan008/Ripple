import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../providers/auth_provider.dart';

/// Splash Screen — PRD §6.1
/// Deep ocean background with floating particles, water droplet logo,
/// gradient app name, auth state listener for auto-redirect
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );

    _logoController.forward();

    // Auto-navigate after checking auth
    Future.delayed(const Duration(seconds: 2), _checkAuth);
  }

  void _checkAuth() {
    if (!mounted) return;
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) {
        if (!mounted) return;
        final nav = GoRouter.of(context);
        if (user != null) {
          nav.go('/home');
        } else {
          nav.go('/login');
        }
      },
      loading: () {
        // Auth not ready yet, retry after a short delay
        Future.delayed(const Duration(milliseconds: 500), _checkAuth);
      },
      error: (_, __) {
        if (!mounted) return;
        GoRouter.of(context).go('/login');
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth changes
    ref.listen<AsyncValue>(authStateProvider, (_, next) {
      next.whenData((user) {
        if (!mounted) return;
        final nav = GoRouter.of(context);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (user != null) {
            nav.go('/home');
          }
        });
      });
    });

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: Stack(
        children: [
          // Floating particles background
          const FloatingParticles(particleCount: 6),

          // Glowing background orbs
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.aquaCore.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.aquaCyan.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Center content
          Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ripple Logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.aquaCyan.withValues(alpha: 0.4),
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

                        const SizedBox(height: 24),

                        // App name with gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.aquaGradient.createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                          child: Text(
                            'Ripple',
                            style: AppTextStyles.display.copyWith(
                              color: Colors.white,
                              fontSize: 42,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Tagline
                        Text(
                          'Connect in liquid-clear conversations',
                          style: AppTextStyles.subtitle,
                        ),

                        const SizedBox(height: 48),

                        // Loading indicator
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.aquaCore.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
