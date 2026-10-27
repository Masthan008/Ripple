import 'package:flutter/material.dart';

/// Draggable Telegram-style circular liquid glass indicator with spring physics and aquatic glow.
class LiquidNavbarDraggableIndicator extends StatefulWidget {
  final double position; // Center X of indicator
  final double baseSize; // Base size for items
  final int itemCount; // Total number of navbar items
  final List<double> snapPositions; // Centers of items
  final Function(double) onDragUpdate;
  final Function(int) onDragEnd;
  final double bottomOffset;
  final double parentWidth; // Width of parent stack container
  final Color? glowColor;
  final double navbarHeight;

  const LiquidNavbarDraggableIndicator({
    super.key,
    required this.position,
    required this.baseSize,
    required this.itemCount,
    required this.snapPositions,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.parentWidth,
    this.bottomOffset = 0,
    this.glowColor,
    this.navbarHeight = 72,
  });

  @override
  State<LiquidNavbarDraggableIndicator> createState() =>
      _LiquidNavbarDraggableIndicatorState();
}

class _LiquidNavbarDraggableIndicatorState
    extends State<LiquidNavbarDraggableIndicator> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0 || widget.snapPositions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Circular diameter matching Telegram active icon bubble
    const double size = 48.0;

    final clampedCenter = widget.position.clamp(
      size / 2,
      widget.parentWidth - size / 2,
    );

    final glow = widget.glowColor ?? const Color(0xFF0EA5E9);

    // Vertically center with the active icon in the tab item
    final bottomPos = widget.bottomOffset + (widget.navbarHeight - size) / 2 + 6;

    return Positioned(
      left: clampedCenter - size / 2,
      bottom: bottomPos,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) {
          final newPos = (widget.position + details.delta.dx).clamp(
            size / 2,
            widget.parentWidth - size / 2,
          );
          widget.onDragUpdate(newPos);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          if (widget.snapPositions.isEmpty) return;

          double closest = widget.snapPositions[0];
          double minDist = (widget.position - closest).abs();

          for (final double p in widget.snapPositions) {
            final dist = (widget.position - p).abs();
            if (dist < minDist) {
              minDist = dist;
              closest = p;
            }
          }
          final index = widget.snapPositions.indexOf(closest);
          if (index != -1) {
            widget.onDragEnd(index);
          }
        },
        child: AnimatedScale(
          scale: _isDragging ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.25, -0.35),
                radius: 0.85,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  glow.withValues(alpha: 0.22),
                  glow.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
