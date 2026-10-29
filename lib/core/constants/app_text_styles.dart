import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ripple Typography System — Modern Geometric Interface Typography
/// Powered by Plus Jakarta Sans for crisp legibility and cyber aesthetic.
class AppTextStyles {
  AppTextStyles._();

  // ─── Display — Plus Jakarta Sans ExtraBold 800, 36sp ────────────
  static TextStyle get display => GoogleFonts.plusJakartaSans(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  // ─── Heading — Plus Jakarta Sans Bold 700, 20sp ─────────────────
  static TextStyle get heading => GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  // ─── Heading Small — Plus Jakarta Sans SemiBold 600, 16sp ───────
  static TextStyle get headingSmall => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  // ─── Body — Plus Jakarta Sans Regular 400, 14sp ────────────────
  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  // ─── Body Small — Plus Jakarta Sans Regular 400, 12sp ─────────
  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  // ─── Caption — Plus Jakarta Sans Light 300, 11sp ───────────────
  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w400,
      );

  // ─── Label — Plus Jakarta Sans SemiBold 600, 12sp ──────────────
  static TextStyle get label => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  // ─── Sender Label (Group) — Plus Jakarta Sans SemiBold 9sp ────
  static TextStyle get senderLabel => GoogleFonts.plusJakartaSans(
        fontSize: 9,
        fontWeight: FontWeight.w600,
      );

  // ─── Button — Plus Jakarta Sans SemiBold 14sp ──────────────────
  static TextStyle get button => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  // ─── Subtitle — Plus Jakarta Sans 13sp ──────────────────
  static TextStyle get subtitle => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      );

  // ─── Chat Bubble — Plus Jakarta Sans Regular 14sp ─────────────────
  static TextStyle get chatBubble => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  // ─── Chat Bubble Small — Plus Jakarta Sans 12sp ─────────────
  static TextStyle get chatBubbleSmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
      );
}
