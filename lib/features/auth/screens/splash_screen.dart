import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/floating_particles.dart';
import '../providers/auth_provider.dart';

/// Splash Screen — PRD §6.1
/// Deep ocean background with floating particles, water droplet logo,
/// gradient app name. Checks auth + registration state before navigating.
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

    // Auto-navigate after splash animation
    Future.delayed(const Duration(seconds: 2), _checkAuthAndNavigate);
  }

  /// Single auth check — reads Firestore directly to avoid
  /// race conditions with stream-based providers.
  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    final user = FirebaseService.auth.currentUser;

    // Not logged in → go to login
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    // User exists — check Firestore for registration status
    try {
      final doc = await FirebaseService.usersCollection
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!doc.exists) {
        // No doc at all — go to login (will trigger Google/email flow)
        context.go('/login');
        return;
      }

      final data = doc.data();
      final hasRegFlag =
          data?.containsKey('isRegistrationComplete') ?? false;

      bool isComplete;
      if (hasRegFlag) {
        isComplete = data!['isRegistrationComplete'] as bool? ?? false;
      } else {
        // Legacy user — no flag, check if they have a name (old registration)
        final name = data?['name'] as String? ?? '';
        isComplete = name.isNotEmpty;
      }

      if (isComplete) {
        context.go('/home');
      } else {
        // Registration not complete — go to register with user data
        context.go(
          '/register?uid=${user.uid}'
          '&name=${Uri.encodeComponent(data?['name'] ?? user.displayName ?? '')}'
          '&email=${Uri.encodeComponent(user.email ?? '')}'
          '&photoUrl=${Uri.encodeComponent(data?['photoUrl'] ?? user.photoURL ?? '')}'
          '&isGoogleSignIn=true',
        );
      }
    } catch (e) {
      // On error, go to login
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NO ref.listen here — splash screen does NOT listen for auth
    // changes. It performs a one-time check in _checkAuthAndNavigate.
    // GoRouter redirect handles all subsequent navigation.

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
