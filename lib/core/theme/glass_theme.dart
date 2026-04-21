import 'package:flutter/material.dart';
import 'theme_models.dart';

/// Glass Morphism helper utilities for the Liquid Glass design system
extension GlassThemeExtension on RippleTheme {
  // ─── Glass Card Decoration ───────────────────────────
  BoxDecoration glassDecoration({
    double borderRadius = 24,
    Color? backgroundColor,
    Color? borderColor,
    double borderWidth = 1,
    List<BoxShadow>? customShadows,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? colors.glassSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? colors.glassBorder,
        width: borderWidth,
      ),
      boxShadow: customShadows ?? shadows.soft,
    );
  }

  // ─── Glass Card with Bioluminescent Edge ────────────────
  BoxDecoration glassDecorationWithBiolume({
    double borderRadius = 24,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colors.glassBorder,
          Colors.transparent,
          colors.primary.withOpacity(0.1),
        ],
      ),
      border: Border.fromBorderSide(
        BorderSide(color: colors.glassBorder, width: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: colors.primary.withOpacity(0.1),
          blurRadius: 20,
          spreadRadius: -5,
        ),
      ],
    );
  }

  // ─── Message Bubble Incoming ─────────────────────────
  BoxDecoration incomingBubbleDecoration() {
    return BoxDecoration(
      color: colors.bubbleIncoming,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      border: Border.all(
        color: colors.glassBorder.withOpacity(0.3),
        width: 0.5,
      ),
    );
  }

  // ─── Message Bubble Outgoing ─────────────────────────
  BoxDecoration outgoingBubbleDecoration() {
    return BoxDecoration(
      gradient: gradients.bubbleOutgoing,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      ),
      border: Border.all(
        color: colors.primary.withOpacity(0.4),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.primary.withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 4), // soft drop shadow
        ),
      ],
    );
  }

  // ─── Bottom Nav Bar Decoration ───────────────────────
  BoxDecoration bottomNavDecoration() {
    return BoxDecoration(
      color: colors.surface.withOpacity(0.8), 
      border: Border(
        top: BorderSide(color: colors.glassBorder, width: 1),
      ),
    );
  }

  // ─── Glass Button Decoration ─────────────────────────
  BoxDecoration glassButtonDecoration({
    double borderRadius = 14,
    bool isPrimary = false,
  }) {
    if (isPrimary) {
      return BoxDecoration(
        gradient: gradients.primary,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows.primaryGlow,
      );
    }
    return BoxDecoration(
      color: colors.glassSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: colors.glassBorder, width: 1),
    );
  }

  // ─── Input Field Decoration ──────────────────────────
  BoxDecoration inputDecoration({
    double borderRadius = 12,
  }) {
    return BoxDecoration(
      color: colors.glassSurface.withOpacity(isDark ? 0.06 : 0.4),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: colors.glassBorder.withOpacity(isDark ? 0.1 : 0.3),
        width: 1,
      ),
    );
  }
}

class GlassTheme {
  // Keep sigma values static for backward compatibility easily without theme
  // if needed elsewhere
  static const double blurHeavy = 28.0;
  static const double blurMedium = 20.0;
  static const double blurLight = 12.0;
}
