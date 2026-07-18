import 'package:flutter/material.dart';

/// Reusable Glass/Aquatic verified badge next to user names
class VerifiedBadge extends StatelessWidget {
  final bool isVerified;
  final double size;
  final EdgeInsetsGeometry padding;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.size = 16,
    this.padding = const EdgeInsets.only(left: 4),
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Image.asset(
        'assets/images/icons8-verified-badge-96.gif',
        width: size,
        height: size,
        // Ensure image fits nicely next to text
        fit: BoxFit.contain,
      ),
    );
  }
}
