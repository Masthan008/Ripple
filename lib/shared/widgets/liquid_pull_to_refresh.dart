import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Custom liquid pull-to-refresh with ripple water effect — theme-aware
class LiquidPullToRefresh extends ConsumerStatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double height;

  const LiquidPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.height = 100,
  });

  @override
  ConsumerState<LiquidPullToRefresh> createState() => _LiquidPullToRefreshState();
}

class _LiquidPullToRefreshState extends ConsumerState<LiquidPullToRefresh>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _dropController;
  double _dragOffset = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          if (notification.metrics.pixels <= 0) {
            setState(() => _dragOffset = 0);
          }
        } else if (notification is ScrollUpdateNotification) {
          if (notification.metrics.pixels < 0) {
            setState(() {
              _dragOffset = -notification.metrics.pixels;
            });
          }
        } else if (notification is ScrollEndNotification) {
          if (_dragOffset > widget.height * 0.8 && !_isRefreshing) {
            _startRefresh();
          } else if (!_isRefreshing) {
            setState(() => _dragOffset = 0);
          }
        }
        return false;
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragOffset > 0 || _isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  final progress = _isRefreshing
                      ? 1.0
                      : math.min(_dragOffset / widget.height, 1.0);
                  return CustomPaint(
                    painter: _WavePainter(
                      progress: progress,
                      wavePhase: _waveController.value * 2 * math.pi,
                      isRefreshing: _isRefreshing,
                      primaryColor: theme.colors.primary,
                      secondaryColor: theme.colors.secondary,
                    ),
                    size: Size(
                      MediaQuery.of(context).size.width,
                      widget.height * progress,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _startRefresh() async {
    setState(() => _isRefreshing = true);
    await widget.onRefresh();
    if (mounted) {
      setState(() {
        _isRefreshing = false;
        _dragOffset = 0;
      });
    }
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double wavePhase;
  final bool isRefreshing;
  final Color primaryColor;
  final Color secondaryColor;

  _WavePainter({
    required this.progress,
    required this.wavePhase,
    required this.isRefreshing,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    // Draw wave
    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height -
          10 +
          math.sin((x / size.width * 4 * math.pi) + wavePhase) * 10 * progress;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, paint);

    // Draw second wave (darker)
    final paint2 = Paint()
      ..color = secondaryColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 5) {
      final y = size.height -
          15 +
          math.sin((x / size.width * 3 * math.pi) + wavePhase + 1) *
              15 *
              progress;
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();

    canvas.drawPath(path2, paint2);

    // Draw ripple circles when refreshing
    if (isRefreshing) {
      final center = Offset(size.width / 2, size.height / 2);
      for (int i = 0; i < 3; i++) {
        final radius = (wavePhase * 10 + i * 20) % 60;
        final opacity = 1 - (radius / 60);
        final ripplePaint = Paint()
          ..color = primaryColor.withOpacity(opacity * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(center, radius, ripplePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
