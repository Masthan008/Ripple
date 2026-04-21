import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';
import 'theme_models.dart';

/// Extension to easily access theme colors in any widget
extension ThemeContext on BuildContext {
  /// Get current RippleTheme from provider
  RippleTheme get rippleTheme {
    // This needs to be called from within a ConsumerWidget or with ref
    throw UnimplementedError('Use ref.watch(rippleThemeProvider) instead');
  }
}

/// Extension on WidgetRef for easy theme access
extension ThemeRef on WidgetRef {
  /// Get current theme colors
  ThemeColors get themeColors => watch(rippleThemeProvider).colors;
  
  /// Get current theme gradients
  ThemeGradients get themeGradients => watch(rippleThemeProvider).gradients;
  
  /// Get current theme shadows
  ThemeShadows get themeShadows => watch(rippleThemeProvider).shadows;
  
  /// Get full theme
  RippleTheme get rippleTheme => watch(rippleThemeProvider);
}

/// Mixin for StatefulWidget to access theme easily
mixin ThemeMixin<T extends StatefulWidget> on State<T> {
  RippleTheme get theme => _theme ?? ThemePresets.aquaOcean;
  RippleTheme? _theme;
  
  void initTheme(WidgetRef ref) {
    _theme = ref.read(rippleThemeProvider);
  }
  
  void updateTheme(RippleTheme newTheme) {
    setState(() => _theme = newTheme);
  }
}

/// Static helper to get theme-aware colors in non-Widget contexts
class ThemeHelper {
  static ThemeColors of(WidgetRef ref) => ref.themeColors;
  static RippleTheme theme(WidgetRef ref) => ref.rippleTheme;
}
