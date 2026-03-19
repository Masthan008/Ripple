import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class LiquidNavbarDraggableIndicator extends StatelessWidget {
  final double position; // Center X of indicator
  final double baseSize; // Base size for 3 items
  final int itemCount; // Total number of navbar items
  final List<double> snapPositions; // Centers of items
  final Function(double) onDragUpdate;
  final Function(int) onDragEnd;
  final double bottomOffset;

  const LiquidNavbarDraggableIndicator({
    super.key,
    required this.position,
    required this.baseSize,
    required this.itemCount,
    required this.snapPositions,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.bottomOffset = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0 || snapPositions.isEmpty) return const SizedBox.shrink();
    
    final screenWidth = MediaQuery.of(context).size.width;

    // Adaptive width based on item count
    final adaptiveWidth = (baseSize * (3.5 / itemCount).clamp(1.0, 1.2));

    // Clamp the center so indicator never goes off-screen
    final clampedCenter = position.clamp(
      adaptiveWidth / 2,
      screenWidth - adaptiveWidth / 2,
    );

    return Positioned(
      left: clampedCenter - adaptiveWidth / 2, // exact center
      bottom: bottomOffset + 5,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final newPos = (position + details.delta.dx).clamp(
            adaptiveWidth / 2,
            screenWidth - adaptiveWidth / 2,
          );
          onDragUpdate(newPos);
        },
        onHorizontalDragEnd: (_) {
          if (snapPositions.isEmpty) return;
          // Snap to nearest measured icon center
          double closest = snapPositions[0];
          double minDist = (position - closest).abs();

          for (double p in snapPositions) {
            final dist = (position - p).abs();
            if (dist < minDist) {
              minDist = dist;
              closest = p;
            }
          }
          final index = snapPositions.indexOf(closest);
          if (index != -1) {
            onDragEnd(index);
          }
        },
        child: LiquidGlassLayer(
          settings: const LiquidGlassSettings(
            lightIntensity: 1.5,
            thickness: 20,
            blur: 1,
          ),
          child: LiquidStretch(
            stretch: 0.7,
            interactionScale: 1.05,
            child: LiquidGlass(
              glassContainsChild: true,
              shape: LiquidRoundedSuperellipse(borderRadius: 30),
              child: GlassGlow(
                child: Container(
                  width: adaptiveWidth,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(adaptiveWidth / 2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
