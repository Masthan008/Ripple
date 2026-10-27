import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';

/// Bespoke Liquid Refresh Indicator with organic surface tension & ripple waves.
/// Adapts dynamically to Light, Dark, and custom themes.
class LiquidRefreshIndicator extends ConsumerStatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double threshold;

  const LiquidRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.threshold = 80.0,
  });

  @override
  ConsumerState<LiquidRefreshIndicator> createState() =>
      _LiquidRefreshIndicatorState();
}

class _LiquidRefreshIndicatorState extends ConsumerState<LiquidRefreshIndicator>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  bool _hasTriggeredHaptic = false;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.extentBefore == 0 &&
          (notification.scrollDelta ?? 0) < 0) {
        setState(() {
          _dragOffset = (_dragOffset - (notification.scrollDelta ?? 0) * 0.5)
              .clamp(0.0, widget.threshold * 1.5);
        });

        if (_dragOffset >= widget.threshold && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          AppHaptics.mediumTap();
        } else if (_dragOffset < widget.threshold) {
          _hasTriggeredHaptic = false;
        }
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        setState(() {
          _dragOffset = (_dragOffset - notification.overscroll * 0.5)
              .clamp(0.0, widget.threshold * 1.5);
        });

        if (_dragOffset >= widget.threshold && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          AppHaptics.mediumTap();
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset >= widget.threshold) {
        _triggerRefresh();
      } else {
        _resetDrag();
      }
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragOffset = widget.threshold;
    });
    _waveController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _waveController.stop();
        _resetDrag();
      }
    }
  }

  void _resetDrag() {
    setState(() {
      _isRefreshing = false;
      _dragOffset = 0.0;
      _hasTriggeredHaptic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final primaryGradient = isDark
        ? const [Color(0xFF0EA5E9), Color(0xFF22D3EE)]
        : const [Color(0xFF1A8CFF), Color(0xFF00C6FF)];
    final rippleColor = isDark
        ? const Color(0xFF22D3EE).withValues(alpha: 0.35)
        : const Color(0xFF1A8CFF).withValues(alpha: 0.25);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: Stack(
        children: [
          // Content displaced smoothly by liquid pull
          AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 300)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _dragOffset > 0 ? _dragOffset * 0.45 : 0,
              0,
            ),
            child: widget.child,
          ),

          // Liquid Canvas Overlay
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max(_dragOffset, widget.threshold),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _LiquidDropPainter(
                      pullDistance: _dragOffset,
                      maxThreshold: widget.threshold,
                      isRefreshing: _isRefreshing,
                      waveProgress: _waveController.value,
                      gradientColors: primaryGradient,
                      rippleColor: rippleColor,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LiquidDropPainter extends CustomPainter {
  final double pullDistance;
  final double maxThreshold;
  final bool isRefreshing;
  final double waveProgress;
  final List<Color> gradientColors;
  final Color rippleColor;

  _LiquidDropPainter({
    required this.pullDistance,
    required this.maxThreshold,
    required this.isRefreshing,
    required this.waveProgress,
    required this.gradientColors,
    required this.rippleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final progress = (pullDistance / maxThreshold).clamp(0.0, 1.4);

    if (isRefreshing) {
      // Concentric oscillating water ripples
      final ripplePaint = Paint()
        ..color = rippleColor.withValues(alpha: (1.0 - waveProgress) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final radius = 18.0 + (waveProgress * 32.0);
      canvas.drawCircle(Offset(centerX, 28), radius, ripplePaint);

      final secondRadius = 10.0 + (((waveProgress + 0.5) % 1.0) * 32.0);
      final secondAlpha = (1.0 - ((waveProgress + 0.5) % 1.0)) * 0.5;
      ripplePaint.color = rippleColor.withValues(alpha: secondAlpha);
      canvas.drawCircle(Offset(centerX, 28), secondRadius, ripplePaint);

      // Core pulsating fluid orb
      final orbPaint = Paint()
        ..shader = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: Offset(centerX, 28), radius: 12));

      canvas.drawCircle(Offset(centerX, 28), 10 + math.sin(waveProgress * math.pi * 2) * 2, orbPaint);
      return;
    }

    // Surface tension fluid elongation
    final dropHeight = pullDistance * 0.65;
    final dropWidth = math.max(12.0, 32.0 * (1.0 - progress * 0.4));
    final dropY = math.min(dropHeight, maxThreshold * 0.85);

    final path = Path();
    path.moveTo(centerX - dropWidth * 1.2, 0);

    // Left curved surface tension neck
    path.cubicTo(
      centerX - dropWidth * 0.8,
      dropY * 0.35,
      centerX - dropWidth * 0.6,
      dropY * 0.7,
      centerX,
      dropY,
    );

    // Right curved surface tension neck
    path.cubicTo(
      centerX + dropWidth * 0.6,
      dropY * 0.7,
      centerX + dropWidth * 0.8,
      dropY * 0.35,
      centerX + dropWidth * 1.2,
      0,
    );
    path.close();

    final dropPaint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(centerX - 40, 0, 80, dropY + 20));

    canvas.drawPath(path, dropPaint);

    // Droplet bottom bulb
    final bulbRadius = math.min(14.0, 6.0 + progress * 8.0);
    canvas.drawCircle(Offset(centerX, dropY), bulbRadius, dropPaint);

    // Specular highlight gleam
    final gleamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(centerX - bulbRadius * 0.3, dropY - bulbRadius * 0.3),
      bulbRadius * 0.28,
      gleamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidDropPainter oldDelegate) {
    return oldDelegate.pullDistance != pullDistance ||
        oldDelegate.isRefreshing != isRefreshing ||
        oldDelegate.waveProgress != waveProgress;
  }
}
