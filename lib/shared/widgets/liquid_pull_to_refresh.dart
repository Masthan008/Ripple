import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart';
import '../../core/utils/haptic_feedback.dart';

/// Redesigned Liquid Pull To Refresh with fluid surface-tension droplet,
/// organic tear elongation, concentric ripple bursts, and theme adaptation.
class LiquidPullToRefresh extends ConsumerStatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double height;

  const LiquidPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.height = 90.0,
  });

  @override
  ConsumerState<LiquidPullToRefresh> createState() =>
      _LiquidPullToRefreshState();
}

class _LiquidPullToRefreshState extends ConsumerState<LiquidPullToRefresh>
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
      duration: const Duration(milliseconds: 1400),
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
              .clamp(0.0, widget.height * 1.6);
        });

        if (_dragOffset >= widget.height && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          AppHaptics.mediumTap();
        } else if (_dragOffset < widget.height) {
          _hasTriggeredHaptic = false;
        }
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        setState(() {
          _dragOffset = (_dragOffset - notification.overscroll * 0.5)
              .clamp(0.0, widget.height * 1.6);
        });

        if (_dragOffset >= widget.height && !_hasTriggeredHaptic) {
          _hasTriggeredHaptic = true;
          AppHaptics.mediumTap();
        }
      }
    } else if (notification is ScrollEndNotification) {
      if (_dragOffset >= widget.height) {
        _triggerRefresh();
      } else {
        _resetDrag();
      }
    }
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragOffset = widget.height;
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

    final primaryColor = theme.colors.primary;
    final secondaryColor = theme.colors.secondary;

    final dropletGradient = isDark
        ? [primaryColor, secondaryColor]
        : [const Color(0xFF1A8CFF), const Color(0xFF00C6FF)];

    final rippleGlow = isDark
        ? secondaryColor.withValues(alpha: 0.35)
        : primaryColor.withValues(alpha: 0.25);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: Stack(
        children: [
          // Content translated smoothly with liquid drag
          AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 320)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _dragOffset > 0 ? _dragOffset * 0.45 : 0,
              0,
            ),
            child: widget.child,
          ),

          // Liquid Droplet & Ripple Waves Canvas
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max(_dragOffset, widget.height),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _BespokeLiquidPainter(
                      pullDistance: _dragOffset,
                      maxThreshold: widget.height,
                      isRefreshing: _isRefreshing,
                      waveProgress: _waveController.value,
                      gradientColors: dropletGradient,
                      rippleColor: rippleGlow,
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

class _BespokeLiquidPainter extends CustomPainter {
  final double pullDistance;
  final double maxThreshold;
  final bool isRefreshing;
  final double waveProgress;
  final List<Color> gradientColors;
  final Color rippleColor;

  _BespokeLiquidPainter({
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
        ..strokeWidth = 2.5;

      final radius1 = 16.0 + (waveProgress * 36.0);
      canvas.drawCircle(Offset(centerX, 28), radius1, ripplePaint);

      final secondProgress = ((waveProgress + 0.5) % 1.0);
      final radius2 = 8.0 + (secondProgress * 36.0);
      ripplePaint.color = rippleColor.withValues(alpha: (1.0 - secondProgress) * 0.45);
      canvas.drawCircle(Offset(centerX, 28), radius2, ripplePaint);

      // Core pulsating glowing fluid orb
      final orbPaint = Paint()
        ..shader = LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: Offset(centerX, 28), radius: 12));

      final pulseRadius = 10.0 + math.sin(waveProgress * math.pi * 2) * 2.5;
      canvas.drawCircle(Offset(centerX, 28), pulseRadius, orbPaint);

      // Specular gleam
      final gleamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX - 3, 25), 3.0, gleamPaint);
      return;
    }

    // Surface tension fluid elongation (droplet forming from top edge)
    final dropHeight = pullDistance * 0.65;
    final dropWidth = math.max(14.0, 36.0 * (1.0 - progress * 0.42));
    final dropY = math.min(dropHeight, maxThreshold * 0.88);

    final path = Path();
    path.moveTo(centerX - dropWidth * 1.25, 0);

    // Left curved fluid neck
    path.cubicTo(
      centerX - dropWidth * 0.85,
      dropY * 0.35,
      centerX - dropWidth * 0.6,
      dropY * 0.72,
      centerX,
      dropY,
    );

    // Right curved fluid neck
    path.cubicTo(
      centerX + dropWidth * 0.6,
      dropY * 0.72,
      centerX + dropWidth * 0.85,
      dropY * 0.35,
      centerX + dropWidth * 1.25,
      0,
    );
    path.close();

    final dropPaint = Paint()
      ..shader = LinearGradient(
        colors: gradientColors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(centerX - 40, 0, 80, dropY + 24));

    canvas.drawPath(path, dropPaint);

    // Droplet bottom bulb
    final bulbRadius = math.min(15.0, 7.0 + progress * 8.0);
    canvas.drawCircle(Offset(centerX, dropY), bulbRadius, dropPaint);

    // Specular highlight gleam (creates the shiny 3D liquid look)
    final gleamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(centerX - bulbRadius * 0.3, dropY - bulbRadius * 0.3),
      bulbRadius * 0.28,
      gleamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BespokeLiquidPainter oldDelegate) {
    return oldDelegate.pullDistance != pullDistance ||
        oldDelegate.isRefreshing != isRefreshing ||
        oldDelegate.waveProgress != waveProgress;
  }
}
