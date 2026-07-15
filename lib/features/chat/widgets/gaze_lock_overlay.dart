import 'dart:ui' show ImageFilter;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../providers/gaze_privacy_provider.dart';

/// Gaze Lock Overlay — Ripple Telepathy™
///
/// Wraps a child widget (typically a message bubble) with an animated
/// frosted glass blur. The blur dissolves when the user is detected
/// looking at the screen, and instantly re-freezes when:
///   - The user looks away
///   - A shoulder surfer is detected
///   - The user's eyes close
///
/// Uses [BackdropFilter] with animated sigma values and a liquid glass
/// gradient overlay for the iconic Ripple aesthetic.
class GazeLockOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const GazeLockOverlay({super.key, required this.child});

  @override
  ConsumerState<GazeLockOverlay> createState() => _GazeLockOverlayState();
}

class _GazeLockOverlayState extends ConsumerState<GazeLockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _blurController;
  late Animation<double> _blurAnimation;
  bool _wasShoulderSurfer = false;

  @override
  void initState() {
    super.initState();
    _blurController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _blurAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _blurController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _blurController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gazeEnabled = ref.watch(telepathyEnabledProvider);
    final shoulderEnabled = ref.watch(antiShoulderSurfingEnabledProvider);
    // If neither feature is on, show child directly
    if (!gazeEnabled && !shoulderEnabled) return widget.child;

    final shouldShow = ref.watch(shouldShowMessagesProvider);
    final isShoulderSurfer = ref.watch(shoulderSurferDetectedProvider);

    // Trigger haptic warning on shoulder surfer detection
    if (isShoulderSurfer && !_wasShoulderSurfer) {
      AppHaptics.heavyTap();
      // Double haptic for urgency
      Future.delayed(const Duration(milliseconds: 100), () {
        AppHaptics.heavyTap();
      });
    }
    _wasShoulderSurfer = isShoulderSurfer;

    // Animate blur
    if (shouldShow) {
      _blurController.forward();
    } else {
      _blurController.reverse();
    }

    return AnimatedBuilder(
      animation: _blurAnimation,
      builder: (context, child) {
        final sigma = _blurAnimation.value;
        final isBlurred = sigma > 0.5;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // The actual message content
              widget.child,

              // Blur overlay
              if (isBlurred)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.aquaCore.withOpacity(
                              isShoulderSurfer ? 0.3 : 0.08,
                            ),
                            AppColors.deepSea.withOpacity(
                              isShoulderSurfer ? 0.4 : 0.12,
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: isShoulderSurfer
                              ? AppColors.errorRed.withOpacity(0.6)
                              : AppColors.glassBorder,
                          width: isShoulderSurfer ? 1.5 : 0.5,
                        ),
                      ),
                      child: Center(
                        child: isShoulderSurfer
                            ? _buildShoulderSurferWarning()
                            : _buildGazeLockIcon(),
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

  Widget _buildGazeLockIcon() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.visibility_off_rounded,
          color: AppColors.aquaCore.withOpacity(0.6),
          size: 14,
        ),
        const SizedBox(width: 6),
        Text(
          'Look to read',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.aquaCore.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildShoulderSurferWarning() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.shield_rounded,
          color: AppColors.errorRed.withOpacity(0.8),
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          'Privacy Protected',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.errorRed.withOpacity(0.8),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Full-screen shoulder surfer lockdown overlay.
/// Place this in the chat screen Stack. It covers the entire screen
/// with an animated frosted glass + warning when a second face appears.
class ShoulderSurferLockdown extends ConsumerStatefulWidget {
  const ShoulderSurferLockdown({super.key});

  @override
  ConsumerState<ShoulderSurferLockdown> createState() =>
      _ShoulderSurferLockdownState();
}

class _ShoulderSurferLockdownState extends ConsumerState<ShoulderSurferLockdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shoulderEnabled = ref.watch(antiShoulderSurfingEnabledProvider);
    final isShoulderSurfer = ref.watch(shoulderSurferDetectedProvider);

    if (!shoulderEnabled || !isShoulderSurfer) return const SizedBox.shrink();

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final pulse = 0.6 + (_pulseController.value * 0.2);
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: AppColors.abyssBackground.withOpacity(pulse),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated shield icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.15),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.errorRed.withOpacity(0.3),
                                  AppColors.errorRed.withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.errorRed.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.shield_rounded,
                              color: AppColors.errorRed,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Ripple Telepathy™',
                      style: AppTextStyles.heading.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Someone else is looking at your screen',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.errorRed.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Messages are hidden for your privacy',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Telepathy status indicator — shows in the chat header as a small
/// pulsing eye icon when Ripple Telepathy is active.
class TelepathyStatusIndicator extends ConsumerWidget {
  const TelepathyStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gazeEnabled = ref.watch(telepathyEnabledProvider);
    final shoulderEnabled = ref.watch(antiShoulderSurfingEnabledProvider);
    if (!gazeEnabled && !shoulderEnabled) return const SizedBox.shrink();

    final shouldShow = ref.watch(shouldShowMessagesProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: shouldShow
            ? AppColors.onlineGreen.withOpacity(0.15)
            : AppColors.errorRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: shouldShow
              ? AppColors.onlineGreen.withOpacity(0.3)
              : AppColors.errorRed.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            shouldShow ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 10,
            color: shouldShow ? AppColors.onlineGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 4),
          Text(
            shouldShow ? 'Telepathy' : 'Locked',
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: shouldShow ? AppColors.onlineGreen : AppColors.errorRed,
            ),
          ),
        ],
      ),
    );
  }
}
