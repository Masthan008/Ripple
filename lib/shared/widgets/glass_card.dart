import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/glass_theme.dart';

/// Reusable frosted glass card with BackdropFilter blur
/// Core visual element of the Liquid Glass design system
/// Supports animated blur via [animateBlur] for dynamic glassmorphism
class GlassCard extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool showShimmer;

  /// When true, blur smoothly animates from 0 to [blur] on first build
  final bool animateBlur;

  /// Duration of the blur animation
  final Duration animateDuration;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = GlassTheme.blurHeavy,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.shadows,
    this.onTap,
    this.showShimmer = true,
    this.animateBlur = false,
    this.animateDuration = const Duration(milliseconds: 600),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);

    Widget card;

    if (animateBlur) {
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: blur),
        duration: animateDuration,
        curve: Curves.easeOutCubic,
        builder: (_, blurValue, child) => _buildCard(blurValue, child!, theme),
        child: _buildInner(theme),
      );
    } else {
      card = _buildCard(blur, _buildInner(theme), theme);
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }

    return card;
  }

  Widget _buildCard(double blurValue, Widget inner, dynamic theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colors.glassSurface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? theme.colors.glassBorder,
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (theme.isDark ? Colors.white : Colors.black).withOpacity(0.05),
                Colors.transparent,
                theme.colors.primary.withOpacity(0.03),
              ],
            ),
            boxShadow: shadows ?? theme.shadows.soft,
          ),
          child: inner,
        ),
      ),
    );
  }

  Widget _buildInner(dynamic theme) {
    return showShimmer
        ? Stack(
            children: [
              child,
              // Shimmer top edge
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        theme.colors.primary.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        : child;
  }
}
