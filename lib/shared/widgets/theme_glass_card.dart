import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassTheme, GlassCard;
import '../../core/theme/theme_provider.dart';
import '../../core/theme/glass_theme.dart';
import '../../features/profile/providers/accessibility_provider.dart';

/// Theme-aware glass card that automatically uses current theme colors
/// Powered by package:liquid_glass_widgets 1.16.0
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
    final accessibility = ref.watch(accessibilityProvider);
    final isDark = theme.isDark;
    final isHighContrast = accessibility.highContrast;

    final glassSettings = isDark
        ? LiquidGlassSettings.ios27Dark
        : LiquidGlassSettings.ios27Light;

    Widget card = Container(
      decoration: isHighContrast
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                width: 1.5,
              ),
            )
          : null,
      child: GlassContainer(
        useOwnLayer: true,
        settings: glassSettings,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        padding: padding ?? const EdgeInsets.all(20),
        margin: margin,
        color: isHighContrast
            ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF))
            : theme.colors.glassSurface,
        child: _buildInner(),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }

    return card;
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
