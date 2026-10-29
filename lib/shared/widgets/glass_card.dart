import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide GlassTheme, GlassCard;
import '../../core/theme/theme_provider.dart';
import '../../core/theme/glass_theme.dart';

/// Reusable frosted glass card with official Liquid Glass shader rendering
/// Powered by package:liquid_glass_widgets 1.16.0
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
    final isDark = theme.isDark;

    final glassSettings = isDark
        ? LiquidGlassSettings.ios27Dark
        : LiquidGlassSettings.ios27Light;

    Widget card = GlassContainer(
      useOwnLayer: true,
      settings: glassSettings,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin,
      color: backgroundColor ?? theme.colors.glassSurface,
      child: _buildInner(theme),
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
                        theme.colors.primary.withValues(alpha: 0.3),
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
