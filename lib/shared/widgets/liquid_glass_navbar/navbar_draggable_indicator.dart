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
  final double parentWidth; // Width of parent stack container

  const LiquidNavbarDraggableIndicator({
    super.key,
    required this.position,
    required this.baseSize,
    required this.itemCount,
    required this.snapPositions,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.parentWidth,
    this.bottomOffset = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0 || snapPositions.isEmpty) return const SizedBox.shrink();

    // Adaptive width based on item count — scaled to fit icon size
    final adaptiveWidth = (baseSize * (2.4 / itemCount).clamp(0.7, 1.0));

    // Clamp the center so indicator never goes off-screen
    final clampedCenter = position.clamp(
      adaptiveWidth / 2,
      parentWidth - adaptiveWidth / 2,
    );

    return Positioned(
      left: clampedCenter - adaptiveWidth / 2, // exact center
      bottom: bottomOffset + 18,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          final newPos = (position + details.delta.dx).clamp(
            adaptiveWidth / 2,
            parentWidth - adaptiveWidth / 2,
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
                  height: adaptiveWidth * 0.6,
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
