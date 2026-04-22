import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_provider.dart';

/// Semantic Aurora Background
/// A beautiful, slowly shifting mesh gradient background using the current theme's primary/secondary colors.
class AuroraBackground extends ConsumerStatefulWidget {
  final Widget child;
  final List<Color>? customColors;
  final double animationSpeed;

  const AuroraBackground({
    super.key, 
    required this.child,
    this.customColors,
    this.animationSpeed = 1.0,
  });

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _random = Random();
  late List<_BlobInfo> _blobs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _blobs = List.generate(4, (index) {
      return _BlobInfo(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 0.5 + _random.nextDouble() * 0.5,
        speedX: (_random.nextDouble() - 0.5) * 0.05,
        speedY: (_random.nextDouble() - 0.5) * 0.05,
        colorIndex: index % 3,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);

    final colors = widget.customColors ?? [
      theme.colors.primary.withOpacity(0.3),
      theme.colors.secondary.withOpacity(0.3),
      theme.colors.accent.withOpacity(0.2),
    ];

    return Stack(
      children: [
        // Background color
        Container(color: theme.colors.background),

        // Animated Aurora Blobs
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            for (var blob in _blobs) {
              blob.x += blob.speedX * widget.animationSpeed;
              blob.y += blob.speedY * widget.animationSpeed;
              
              if (blob.x < -0.2 || blob.x > 1.2) blob.speedX *= -1;
              if (blob.y < -0.2 || blob.y > 1.2) blob.speedY *= -1;
            }

            return CustomPaint(
              painter: _AuroraPainter(blobs: _blobs, colors: colors),
              size: Size.infinite,
            );
          },
        ),

        // Massive blur layer to blend the blobs into an aurora
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(color: Colors.transparent),
        ),

        // Foreground content
        widget.child,
      ],
    );
  }
}

class _BlobInfo {
  double x;
  double y;
  double radius;
  double speedX;
  double speedY;
  int colorIndex;

  _BlobInfo({
    required this.x,
    required this.y,
    required this.radius,
    required this.speedX,
    required this.speedY,
    required this.colorIndex,
  });
}

class _AuroraPainter extends CustomPainter {
  final List<_BlobInfo> blobs;
  final List<Color> colors;

  _AuroraPainter({required this.blobs, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    for (var blob in blobs) {
      final paint = Paint()
        ..color = colors[blob.colorIndex]
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

      canvas.drawCircle(
        Offset(blob.x * size.width, blob.y * size.height),
        blob.radius * size.width * 0.8,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
