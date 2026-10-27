import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/theme_models.dart';

/// A high-performance liquid glassmorphic background container.
///
/// Combines hardware-accelerated [BackdropFilter] with specular light refraction,
/// dual-layer glass border gradients, superellipse rounding, and soft ambient drop shadows.
class LiquidNavbarBackground extends StatelessWidget {
  /// The width of the navbar background
  final double width;

  /// The height of the navbar background
  final double height;

  /// The child widget to display inside the background
  final Widget child;

  /// The active theme data
  final RippleTheme theme;

  const LiquidNavbarBackground({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.isDark ? 0.35 : 0.08),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              color: theme.colors.glassSurface,
              border: Border.all(
                color: theme.colors.glassBorder,
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                // Top-edge specular light refraction sheen (Telegram liquid glass aesthetic)
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(theme.isDark ? 0.3 : 0.6),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
