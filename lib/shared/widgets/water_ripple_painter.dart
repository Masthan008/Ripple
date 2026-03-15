import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/haptic_feedback.dart';

/// Water ripple CustomPainter — draws 3 expanding rings on tap
/// From PRD §5.3
class WaterRipplePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;
  final Offset center;

  WaterRipplePainter({
    required this.progress,
    required this.color,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final delay = i * 0.15;
      final p = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final radius = p * 120.0;
      final opacity = (1 - p) * 0.6;
      if (opacity <= 0) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 * (1 - p),
      );
    }
  }

  @override
  bool shouldRepaint(WaterRipplePainter oldDelegate) =>
      progress != oldDelegate.progress || center != oldDelegate.center;
}

/// Widget wrapper for water ripple effect on tap
class WaterRippleEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;

  const WaterRippleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor = AppColors.aquaCore,
  });

  @override
  State<WaterRippleEffect> createState() => _WaterRippleEffectState();
}

class _WaterRippleEffectState extends State<WaterRippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _rippleCenter = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    AppHaptics.lightTap();
    setState(() {
      _rippleCenter = details.localPosition;
      _controller.forward(from: 0);
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => CustomPaint(
          painter: WaterRipplePainter(
            progress: _controller.value,
            color: widget.rippleColor,
            center: _rippleCenter,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
