import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/glass_theme.dart';

/// Theme-aware glass card that automatically uses current theme colors
/// Use this instead of GlassCard for dynamic theming
class ThemeGlassCard extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool showShimmer;
  final bool animateBlur;
  final Duration animateDuration;

  const ThemeGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = GlassTheme.blurHeavy,
    this.padding,
    this.margin,
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
        child: _buildInner(),
      );
    } else {
      card = _buildCard(blur, _buildInner(), theme);
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
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
            color: theme.colors.glassSurface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: theme.colors.glassBorder,
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.transparent,
                theme.colors.primary.withOpacity(0.03),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: inner,
        ),
      ),
    );
  }

  Widget _buildInner() {
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x4DFFFFFF),
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

/// Animated theme glass card with press effect
class AnimatedThemeGlassCard extends ConsumerStatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool showShimmer;

  const AnimatedThemeGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.blur = GlassTheme.blurHeavy,
    this.padding,
    this.margin,
    this.onTap,
    this.showShimmer = true,
  });

  @override
  ConsumerState<AnimatedThemeGlassCard> createState() => _AnimatedThemeGlassCardState();
}

class _AnimatedThemeGlassCardState extends ConsumerState<AnimatedThemeGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(_) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: ThemeGlassCard(
          borderRadius: widget.borderRadius,
          blur: widget.blur,
          padding: widget.padding,
          margin: widget.margin,
          showShimmer: widget.showShimmer,
          child: widget.child,
        ),
      ),
    );
  }
}
