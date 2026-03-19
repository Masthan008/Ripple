import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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

  const LiquidNavbarBackground({
    super.key,
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(thickness: 20, blur: 2),
      child: LiquidGlass(
        shape: LiquidRoundedSuperellipse(borderRadius: 30),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(35),
            color: const Color(0xFF0A1628).withOpacity(0.5), // Match RIPPLE theme a bit
          ),
          child: child,
        ),
      ),
    );
  }
}
