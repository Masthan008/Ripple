import 'package:flutter/material.dart';

/// Google "G" logo — simple, clean, recognizable
/// Uses 4 colored container segments to form the G shape
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
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: size * 0.6,
            fontWeight: FontWeight.w700,
            height: 1.1,
            foreground: Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEA4335), // Red
                  Color(0xFFFBBC05), // Yellow
                  Color(0xFF34A853), // Green
                  Color(0xFF4285F4), // Blue
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
          ),
        ),
      ),
    );
  }
}
