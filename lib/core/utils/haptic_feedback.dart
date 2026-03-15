import 'package:flutter/services.dart';

/// Centralized haptic feedback utility for micro-interactions.
class AppHaptics {
  AppHaptics._();

  /// Light tap — button presses, toggles
  static void lightTap() => HapticFeedback.lightImpact();

  /// Medium tap — sending messages, confirmations
  static void mediumTap() => HapticFeedback.mediumImpact();

  /// Heavy tap — destructive actions, long-press
  static void heavyTap() => HapticFeedback.heavyImpact();

  /// Success vibration — message sent, AI completed
  static void success() => HapticFeedback.mediumImpact();

  /// Selection tick — picker scrolls, tab switches
  static void selectionTick() => HapticFeedback.selectionClick();
}
