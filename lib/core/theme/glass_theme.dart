import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Glass Morphism helper utilities for the Liquid Glass design system
class GlassTheme {
  GlassTheme._();

  // ─── Glass Card Decoration ───────────────────────────
  static BoxDecoration glassDecoration({
    double borderRadius = 24,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 1,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.glassPanel,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.glassBorder,
        width: borderWidth,
      ),
      boxShadow: shadows,
    );
  }

  // ─── Glass Card with Shimmer Top Edge ────────────────
  static BoxDecoration glassDecorationWithShimmer({
    double borderRadius = 24,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x1FFFFFFF),
          Colors.transparent,
          Color(0x0F0EA5E9),
        ],
      ),
      border: const Border(
        top: BorderSide(color: Color(0x40FFFFFF), width: 1),
        left: BorderSide(color: Color(0x1FFFFFFF), width: 1),
        right: BorderSide(color: Color(0x0AFFFFFF), width: 0.5),
        bottom: BorderSide(color: Color(0x0AFFFFFF), width: 0.5),
      ),
    );
  }

  // ─── Message Bubble Incoming ─────────────────────────
  static BoxDecoration incomingBubbleDecoration() {
    return const BoxDecoration(
      color: AppColors.msgIn,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      border: Border.fromBorderSide(
        BorderSide(color: AppColors.glassBorder, width: 0.5),
      ),
    );
  }

  // ─── Message Bubble Outgoing ─────────────────────────
  static BoxDecoration outgoingBubbleDecoration() {
    return const BoxDecoration(
      gradient: AppColors.msgOutGradient,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      border: Border.fromBorderSide(
        BorderSide(color: Color(0x400EA5E9), width: 0.5),
      ),
    );
  }

  // ─── Bottom Nav Bar Decoration ───────────────────────
  static BoxDecoration bottomNavDecoration() {
    return const BoxDecoration(
      color: Color(0xCC060D1A), // 80% abyss
      border: Border(
        top: BorderSide(color: Color(0x0FFFFFFF), width: 1),
      ),
    );
  }

  // ─── Glass Button Decoration ─────────────────────────
  static BoxDecoration glassButtonDecoration({
    double borderRadius = 14,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return BoxDecoration(
        gradient: AppColors.buttonGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppColors.aquaGlow,
      );
    }
    return BoxDecoration(
      color: AppColors.glassPanel,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: AppColors.glassBorder, width: 1),
    );
  }

  // ─── Input Field Decoration ──────────────────────────
  static BoxDecoration inputDecoration({
    double borderRadius = 12,
  }) {
    return BoxDecoration(
      color: const Color(0x0FFFFFFF), // 6% white
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: const Color(0x17FFFFFF), // 9% white
        width: 1,
      ),
    );
  }

  // ─── Blur Sigma Values ───────────────────────────────
  static const double blurHeavy = 28.0;
  static const double blurMedium = 20.0;
  static const double blurLight = 12.0;
}
