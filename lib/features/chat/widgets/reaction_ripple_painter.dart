import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Water ripple animation painter for reaction feedback
class ReactionRipplePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;

  ReactionRipplePainter({
    required this.progress,
    this.color = AppColors.aquaCore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 1.5;

    // Draw 3 expanding ripple circles
    for (int i = 0; i < 3; i++) {
      final delay = i * 0.15;
      final adjustedProgress = (progress - delay).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final radius = maxRadius * adjustedProgress;
      final opacity = (1.0 - adjustedProgress) * 0.3;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - adjustedProgress);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ReactionRipplePainter old) =>
      old.progress != progress;
}

/// Widget that wraps a child with a ripple animation overlay
class ReactionRippleOverlay extends StatefulWidget {
  final Widget child;
  final bool trigger;
  final VoidCallback? onComplete;

  const ReactionRippleOverlay({
    super.key,
    required this.child,
    this.trigger = false,
    this.onComplete,
  });

  @override
  State<ReactionRippleOverlay> createState() =>
      _ReactionRippleOverlayState();
}

class _ReactionRippleOverlayState extends State<ReactionRippleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(ReactionRippleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: ReactionRipplePainter(progress: _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
