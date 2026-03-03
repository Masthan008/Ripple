import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

/// Shimmer loading placeholder with ocean theme
class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoader({
    super.key,
    this.width = double.infinity,
    this.height = 60,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.glassPanel,
      highlightColor: AppColors.aquaCore.withValues(alpha: 0.1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.glassPanel,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Circle shimmer for avatars
  static Widget circle({double size = 48}) {
    return Shimmer.fromColors(
      baseColor: AppColors.glassPanel,
      highlightColor: AppColors.aquaCore.withValues(alpha: 0.1),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.glassPanel,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// List of shimmer items
  static Widget list({int count = 5, double itemHeight = 72}) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ShimmerLoader(height: itemHeight),
        ),
      ),
    );
  }
}
