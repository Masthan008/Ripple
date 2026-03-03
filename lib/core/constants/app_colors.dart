import 'package:flutter/material.dart';

/// Ripple Color System — Liquid Glass × Aquatic AI
/// Based on PRD §4.1 color palette
class AppColors {
  AppColors._();

  // ─── Primary Brand Colors ────────────────────────────
  static const Color aquaCore = Color(0xFF0EA5E9);
  static const Color aquaCyan = Color(0xFF22D3EE);
  static const Color deepSea = Color(0xFF0C4A6E);

  // ─── Background ──────────────────────────────────────
  static const Color abyssBackground = Color(0xFF060D1A);

  // ─── Text Colors ─────────────────────────────────────
  static const Color lightWave = Color(0xFF7DD3FC);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0x8CFFFFFF); // 55% white
  static const Color textMuted = Color(0x66FFFFFF); // 40% white

  // ─── Glass Morphism ──────────────────────────────────
  static const Color glassPanel = Color(0x14FFFFFF); // 8% white
  static const Color glassBorder = Color(0x2DFFFFFF); // 18% white
  static const Color glassBorderLight = Color(0x0FFFFFFF); // 6% white

  // ─── Status Colors ───────────────────────────────────
  static const Color onlineGreen = Color(0xFF22C55E);
  static const Color offlineGray = Color(0xFF6B7280);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningAmber = Color(0xFFF59E0B);

  // ─── Message Bubbles ─────────────────────────────────
  static const Color msgIn = Color(0x12FFFFFF); // 7% white
  static const Color msgOut = Color(0x590EA5E9); // 35% aquaCore

  // ─── Gradients ───────────────────────────────────────
  static const LinearGradient aquaGradient = LinearGradient(
    colors: [aquaCore, aquaCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient msgOutGradient = LinearGradient(
    colors: [Color(0x590EA5E9), Color(0x4038BDF8)],
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
      Color(0x1FFFFFFF),
      Colors.transparent,
      Color(0x0F0EA5E9),
    ],
  );

  // ─── Shadows ─────────────────────────────────────────
  static List<BoxShadow> get aquaGlow => [
        BoxShadow(
          color: aquaCore.withValues(alpha: 0.18),
          blurRadius: 20,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get cyanGlow => [
        BoxShadow(
          color: aquaCyan.withValues(alpha: 0.25),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];
}
