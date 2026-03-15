import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Ripple Typography System — PRD §4.2
/// Nunito for display/headings, DM Sans for body text
class AppTextStyles {
  AppTextStyles._();

  // ─── Display — Nunito ExtraBold 800, 36sp ────────────
  static TextStyle get display => GoogleFonts.nunito(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  // ─── Heading — Nunito Bold 700, 20sp ─────────────────
  static TextStyle get heading => GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // ─── Heading Small — Nunito SemiBold 600, 16sp ───────
  static TextStyle get headingSmall => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ─── Body — DM Sans Regular 400, 14sp ────────────────
  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  // ─── Body Small — DM Sans Regular 400, 12sp ─────────
  static TextStyle get bodySmall => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  // ─── Caption — DM Sans Light 300, 11sp ───────────────
  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w300,
        color: AppColors.textSecondary,
      );

  // ─── Label — DM Sans SemiBold 600, 12sp ──────────────
  static TextStyle get label => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ─── Sender Label (Group) — DM Sans SemiBold 9sp ────
  static TextStyle get senderLabel => GoogleFonts.dmSans(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: AppColors.aquaCyan,
      );

  // ─── Button — DM Sans SemiBold 14sp ──────────────────
  static TextStyle get button => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // ─── Subtitle — DM Sans Light 13sp ──────────────────
  static TextStyle get subtitle => GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: AppColors.textSecondary,
      );

  // ─── Chat Bubble — Inter Regular 14sp ─────────────────
  static TextStyle get chatBubble => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  // ─── Chat Bubble Small — Inter Light 12sp ─────────────
  static TextStyle get chatBubbleSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: AppColors.textSecondary,
        height: 1.3,
      );
}
