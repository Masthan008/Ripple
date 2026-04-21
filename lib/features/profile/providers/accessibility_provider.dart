import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility settings for inclusive design
/// High contrast, reduced motion, larger text, screen reader optimizations
class AccessibilitySettings {
  final bool highContrast;
  final bool reducedMotion;
  final bool largerText;
  final bool screenReaderOptimized;
  final bool colorBlindMode;
  final double textScale;

  const AccessibilitySettings({
    this.highContrast = false,
    this.reducedMotion = false,
    this.largerText = false,
    this.screenReaderOptimized = false,
    this.colorBlindMode = false,
    this.textScale = 1.0,
  });

  AccessibilitySettings copyWith({
    bool? highContrast,
    bool? reducedMotion,
    bool? largerText,
    bool? screenReaderOptimized,
    bool? colorBlindMode,
    double? textScale,
  }) {
    return AccessibilitySettings(
      highContrast: highContrast ?? this.highContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      largerText: largerText ?? this.largerText,
      screenReaderOptimized: screenReaderOptimized ?? this.screenReaderOptimized,
      colorBlindMode: colorBlindMode ?? this.colorBlindMode,
      textScale: textScale ?? this.textScale,
    );
  }

  Map<String, dynamic> toJson() => {
    'highContrast': highContrast,
    'reducedMotion': reducedMotion,
    'largerText': largerText,
    'screenReaderOptimized': screenReaderOptimized,
    'colorBlindMode': colorBlindMode,
    'textScale': textScale,
  };

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    return AccessibilitySettings(
      highContrast: json['highContrast'] ?? false,
      reducedMotion: json['reducedMotion'] ?? false,
      largerText: json['largerText'] ?? false,
      screenReaderOptimized: json['screenReaderOptimized'] ?? false,
      colorBlindMode: json['colorBlindMode'] ?? false,
      textScale: json['textScale']?.toDouble() ?? 1.0,
    );
  }
}

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  static const _prefsKey = 'accessibility_settings';

  AccessibilityNotifier() : super(const AccessibilitySettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString != null) {
      try {
        final json = Map<String, dynamic>.from(
          Map<String, dynamic>.from(
            jsonString.split(',').fold<Map<String, dynamic>>({}, (map, pair) {
              final parts = pair.split(':');
              if (parts.length == 2) {
                map[parts[0]] = parts[1] == 'true' ? true : parts[1] == 'false' ? false : double.tryParse(parts[1]) ?? parts[1];
              }
              return map;
            }),
          ),
        );
        state = AccessibilitySettings.fromJson(json);
      } catch (e) {
        debugPrint('Error loading accessibility settings: $e');
      }
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final json = state.toJson();
    final jsonString = json.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString(_prefsKey, jsonString);
  }

  void toggleHighContrast(bool value) {
    state = state.copyWith(highContrast: value);
    _saveSettings();
  }

  void toggleReducedMotion(bool value) {
    state = state.copyWith(reducedMotion: value);
    _saveSettings();
  }

  void toggleLargerText(bool value) {
    state = state.copyWith(
      largerText: value,
      textScale: value ? 1.25 : 1.0,
    );
    _saveSettings();
  }

  void toggleScreenReaderOptimized(bool value) {
    state = state.copyWith(screenReaderOptimized: value);
    _saveSettings();
  }

  void toggleColorBlindMode(bool value) {
    state = state.copyWith(colorBlindMode: value);
    _saveSettings();
  }

  void setTextScale(double scale) {
    state = state.copyWith(
      textScale: scale,
      largerText: scale > 1.1,
    );
    _saveSettings();
  }

  /// Check if animations should be reduced
  bool get shouldReduceMotion => state.reducedMotion;

  /// Get accessible color with high contrast if enabled
  Color getAccessibleColor(Color normalColor, Color highContrastColor) {
    return state.highContrast ? highContrastColor : normalColor;
  }
}

/// Effective text scale getter
extension AccessibilitySettingsExtension on AccessibilitySettings {
  double get effectiveTextScale {
    if (largerText) return 1.25;
    return textScale;
  }
}

final accessibilityProvider = StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
  (ref) => AccessibilityNotifier(),
);

/// Provider to check if reduced motion is enabled
final reducedMotionProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).reducedMotion;
});

/// Provider for effective text scale
final textScaleProvider = Provider<double>((ref) {
  return ref.watch(accessibilityProvider).effectiveTextScale;
});

/// Extension for checking accessibility in widgets
extension AccessibilityContext on BuildContext {
  bool get highContrast => 
      ProviderScope.containerOf(this).read(accessibilityProvider).highContrast;
  
  bool get reducedMotion => 
      ProviderScope.containerOf(this).read(accessibilityProvider).reducedMotion;
  
  double get textScale => 
      ProviderScope.containerOf(this).read(accessibilityProvider).effectiveTextScale;
}

/// Widget that applies accessibility settings to child
class AccessibilityWrapper extends ConsumerWidget {
  final Widget child;

  const AccessibilityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibility = ref.watch(accessibilityProvider);
    
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: accessibility.effectiveTextScale,
        boldText: accessibility.highContrast,
      ),
      child: AnimatedTheme(
        data: accessibility.highContrast 
          ? _getHighContrastTheme(context)
          : Theme.of(context),
        duration: accessibility.reducedMotion 
          ? Duration.zero 
          : const Duration(milliseconds: 300),
        child: child,
      ),
    );
  }

  ThemeData _getHighContrastTheme(BuildContext context) {
    final baseTheme = Theme.of(context);
    return baseTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: baseTheme.colorScheme.copyWith(
        surface: Colors.black,
        onSurface: Colors.white,
        primary: Colors.cyan,
        onPrimary: Colors.black,
        secondary: Colors.yellow,
        onSecondary: Colors.black,
      ),
    );
  }
}

/// Accessibility-aware animation wrapper
class AccessibleAnimation extends ConsumerWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AccessibleAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedMotion = ref.watch(reducedMotionProvider);
    
    return AnimatedSwitcher(
      duration: reducedMotion ? Duration.zero : duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      child: child,
    );
  }
}
