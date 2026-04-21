import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ripple Typography System — PRD §4.2
/// Nunito for display/headings, DM Sans for body text
/// NOTE: Colors are NOT hardcoded here. They inherit from ThemeData.textTheme
/// or should be set via .copyWith(color: theme.colors.textPrimary) at the widget level.
class AppTextStyles {
  AppTextStyles._();

  // ─── Display — Nunito ExtraBold 800, 36sp ────────────
  static TextStyle get display => GoogleFonts.nunito(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  // ─── Heading — Nunito Bold 700, 20sp ─────────────────
  static TextStyle get heading => GoogleFonts.nunito(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      );

  // ─── Heading Small — Nunito SemiBold 600, 16sp ───────
  static TextStyle get headingSmall => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  // ─── Body — DM Sans Regular 400, 14sp ────────────────
  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  // ─── Body Small — DM Sans Regular 400, 12sp ─────────
  static TextStyle get bodySmall => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  // ─── Caption — DM Sans Light 300, 11sp ───────────────
  static TextStyle get caption => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w300,
      );

  // ─── Label — DM Sans SemiBold 600, 12sp ──────────────
  static TextStyle get label => GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  // ─── Sender Label (Group) — DM Sans SemiBold 9sp ────
  static TextStyle get senderLabel => GoogleFonts.dmSans(
        fontSize: 9,
        fontWeight: FontWeight.w600,
      );

  // ─── Button — DM Sans SemiBold 14sp ──────────────────
  static TextStyle get button => GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  // ─── Subtitle — DM Sans Light 13sp ──────────────────
  static TextStyle get subtitle => GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w300,
      );

  // ─── Chat Bubble — Inter Regular 14sp ─────────────────
  static TextStyle get chatBubble => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // ─── Chat Bubble Small — Inter Light 12sp ─────────────
  static TextStyle get chatBubbleSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        height: 1.3,
      );
}
