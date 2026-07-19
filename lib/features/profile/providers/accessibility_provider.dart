import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Accessibility settings for inclusive design
class AccessibilitySettings {
  final bool highContrast;
  final bool reducedMotion;
  final bool largerText;
  final bool screenReaderOptimized;
  final bool colorBlindMode;
  final bool hapticFeedback;
  final bool textToSpeech;
  final bool largeTapTargets;
  final double textScale;

  const AccessibilitySettings({
    this.highContrast = false,
    this.reducedMotion = false,
    this.largerText = false,
    this.screenReaderOptimized = false,
    this.colorBlindMode = false,
    this.hapticFeedback = true,
    this.textToSpeech = false,
    this.largeTapTargets = false,
    this.textScale = 1.0,
  });

  AccessibilitySettings copyWith({
    bool? highContrast,
    bool? reducedMotion,
    bool? largerText,
    bool? screenReaderOptimized,
    bool? colorBlindMode,
    bool? hapticFeedback,
    bool? textToSpeech,
    bool? largeTapTargets,
    double? textScale,
  }) {
    return AccessibilitySettings(
      highContrast: highContrast ?? this.highContrast,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      largerText: largerText ?? this.largerText,
      screenReaderOptimized: screenReaderOptimized ?? this.screenReaderOptimized,
      colorBlindMode: colorBlindMode ?? this.colorBlindMode,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      textToSpeech: textToSpeech ?? this.textToSpeech,
      largeTapTargets: largeTapTargets ?? this.largeTapTargets,
      textScale: textScale ?? this.textScale,
    );
  }

  Map<String, dynamic> toJson() => {
    'highContrast': highContrast,
    'reducedMotion': reducedMotion,
    'largerText': largerText,
    'screenReaderOptimized': screenReaderOptimized,
    'colorBlindMode': colorBlindMode,
    'hapticFeedback': hapticFeedback,
    'textToSpeech': textToSpeech,
    'largeTapTargets': largeTapTargets,
    'textScale': textScale,
  };

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) {
    return AccessibilitySettings(
      highContrast: json['highContrast'] ?? false,
      reducedMotion: json['reducedMotion'] ?? false,
      largerText: json['largerText'] ?? false,
      screenReaderOptimized: json['screenReaderOptimized'] ?? false,
      colorBlindMode: json['colorBlindMode'] ?? false,
      hapticFeedback: json['hapticFeedback'] ?? true,
      textToSpeech: json['textToSpeech'] ?? false,
      largeTapTargets: json['largeTapTargets'] ?? false,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class AccessibilityNotifier extends StateNotifier<AccessibilitySettings> {
  static const _prefsKey = 'accessibility_settings_v2';

  AccessibilityNotifier() : super(const AccessibilitySettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString != null) {
        final map = jsonDecode(jsonString) as Map<String, dynamic>;
        state = AccessibilitySettings.fromJson(map);
      }
    } catch (e) {
      debugPrint('Error loading accessibility settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('Error saving accessibility settings: $e');
    }
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

  void toggleHapticFeedback(bool value) {
    state = state.copyWith(hapticFeedback: value);
    _saveSettings();
  }

  void toggleTextToSpeech(bool value) {
    state = state.copyWith(textToSpeech: value);
    _saveSettings();
  }

  void toggleLargeTapTargets(bool value) {
    state = state.copyWith(largeTapTargets: value);
    _saveSettings();
  }

  void setTextScale(double scale) {
    state = state.copyWith(
      textScale: scale,
      largerText: scale > 1.1,
    );
    _saveSettings();
  }

  void resetAll() {
    state = const AccessibilitySettings();
    _saveSettings();
  }
}

/// Effective text scale getter
extension AccessibilitySettingsExtension on AccessibilitySettings {
  double get effectiveTextScale {
    if (largerText && textScale == 1.0) return 1.25;
    return textScale;
  }
}

final accessibilityProvider = StateNotifierProvider<AccessibilityNotifier, AccessibilitySettings>(
  (ref) => AccessibilityNotifier(),
);

final reducedMotionProvider = Provider<bool>((ref) {
  return ref.watch(accessibilityProvider).reducedMotion;
});

final textScaleProvider = Provider<double>((ref) {
  return ref.watch(accessibilityProvider).effectiveTextScale;
});

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
        textScaler: TextScaler.linear(accessibility.effectiveTextScale),
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
