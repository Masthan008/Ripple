import 'package:flutter/material.dart';

/// Ripple Color System — Liquid Glass × Aquatic AI
/// Based on PRD §4.1 color palette
class AppColors {
  AppColors._();

  // ─── Primary Brand Colors ────────────────────────────
  static const Color aquaCore = Color(0xFF0EA5E9);
  static const Color aquaCyan = Color(0xFF22D3EE);
  static const Color deepSea = Color(0xFF0C4A6E);
  static const Color biolume = Color(0xFF38BDF8); // New: Bioluminescent highlight
  static const Color abyssDeep = Color(0xFF020617); // New: Deeper ocean black

  // ─── Background ──────────────────────────────────────
  static const Color abyssBackground = Color(0xFF060D1A);

  // ─── Text Colors ─────────────────────────────────────
  static const Color lightWave = Color(0xFF7DD3FC);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xCCFFFFFF); // Increased to 80% for readability
  static const Color textMuted = Color(0x80FFFFFF); // Increased to 50% for readability

  // ─── Glass Morphism ──────────────────────────────────
  static const Color glassPanel = Color(0x1AFFFFFF); // Increased to 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // Increased to 20% white
  static const Color glassBorderLight = Color(0x14FFFFFF); // 8% white
  static const Color glassTintLight = Color(0x0F22D3EE); // subtle cyan tint
  static const Color glassTintDark = Color(0x0F0C4A6E); // subtle deep blue tint
  static const Color glassGlow = Color(0x400EA5E9); // Aqua glow for edges

  // ─── Status Colors ───────────────────────────────────
  static const Color onlineGreen = Color(0xFF4ADE80); // More vibrant
  static const Color offlineGray = Color(0xFF94A3B8); // Softer gray
  static const Color errorRed = Color(0xFFF87171); // More vibrant
  static const Color warningAmber = Color(0xFFFBBF24); // More vibrant

  // ─── Message Bubbles ─────────────────────────────────
  static const Color msgIn = Color(0x1AFFFFFF); // 10% white
  static const Color msgOut = Color(0x660EA5E9); // 40% aquaCore

  // ─── Gradients ───────────────────────────────────────
  static const LinearGradient aquaGradient = LinearGradient(
    colors: [aquaCore, aquaCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient biolumeGradient = LinearGradient(
    colors: [biolume, aquaCyan],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient msgOutGradient = LinearGradient(
    colors: [Color(0x660EA5E9), Color(0x4D38BDF8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x2DFFFFFF),
      Colors.transparent,
      Color(0x1A0EA5E9),
    ],
  );

  // ─── Shadows ─────────────────────────────────────────
  static List<BoxShadow> get aquaGlow => [
        BoxShadow(
          color: aquaCore.withValues(alpha: 0.25),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ];

  static List<BoxShadow> get cyanGlow => [
        BoxShadow(
          color: aquaCyan.withValues(alpha: 0.35),
          blurRadius: 20,
          spreadRadius: -1,
        ),
      ];

  static List<BoxShadow> get biolumeGlow => [
        BoxShadow(
          color: biolume.withValues(alpha: 0.4),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ];
}
