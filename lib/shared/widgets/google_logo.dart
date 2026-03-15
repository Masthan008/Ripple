import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Google logo — precise SVG format
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        'assets/images/google.svg',
        width: size * 0.7,
        height: size * 0.7,
      ),
    );
  }
}
