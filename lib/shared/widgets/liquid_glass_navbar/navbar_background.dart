import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../core/theme/theme_models.dart';

/// A glassmorphic background container for the navbar.
///
/// This widget provides the visual background for the navbar
/// using liquid glass effects.
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
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(thickness: 20, blur: 2),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 36),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            color: theme.colors.glassSurface,
            border: Border.all(
              color: theme.colors.glassBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(theme.isDark ? 0.35 : 0.08),
                blurRadius: 16,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
