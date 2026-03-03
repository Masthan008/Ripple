import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Official Google "G" logo built with colored arcs — accurate brand rendering
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      padding: EdgeInsets.all(size * 0.1),
      child: CustomPaint(
        size: Size(size * 0.8, size * 0.8),
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  // Official Google brand colors
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;
    final strokeWidth = size.width * 0.2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Draw 4 colored arcs forming the G shape
    // Blue (right side, from center to top-right) — this is the main arc
    paint.color = _blue;
    canvas.drawArc(rect, -math.pi / 6, math.pi / 3 + math.pi / 12, false, paint);

    // Green (bottom segment)
    paint.color = _green;
    canvas.drawArc(rect, math.pi / 6 + math.pi / 12, math.pi / 3, false, paint);

    // Yellow (left-bottom segment)
    paint.color = _yellow;
    canvas.drawArc(rect, math.pi / 2 + math.pi / 12, math.pi / 3, false, paint);

    // Red (top segment)
    paint.color = _red;
    canvas.drawArc(rect, math.pi * 5 / 6 + math.pi / 12, math.pi / 2.5, false, paint);

    // Blue again for the top-right open arc
    paint.color = _blue;
    canvas.drawArc(rect, -math.pi / 2, math.pi / 3 + math.pi / 12, false, paint);

    // Blue horizontal bar (crossbar of the G)
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;

    final barHeight = strokeWidth * 0.9;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - size.width * 0.02,
          center.dy - barHeight / 2,
          radius + strokeWidth / 2,
          barHeight,
        ),
        Radius.circular(barHeight * 0.1),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
