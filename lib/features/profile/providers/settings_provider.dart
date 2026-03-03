import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Theme Provider ─────────────────────────────────────
final themeProvider = StateNotifierProvider<ThemeNotifier, String>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<String> {
  ThemeNotifier() : super('dark_ocean') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('app_theme') ?? 'dark_ocean';
  }

  Future<void> setTheme(String theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
  }
}

// ─── Bubble Style Provider ──────────────────────────────
final bubbleStyleProvider = StateNotifierProvider<BubbleStyleNotifier, String>((ref) {
  return BubbleStyleNotifier();
});

class BubbleStyleNotifier extends StateNotifier<String> {
  BubbleStyleNotifier() : super('rounded') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('bubble_style') ?? 'rounded';
  }

  Future<void> setStyle(String style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bubble_style', style);
  }
}

// ─── Font Size Provider ─────────────────────────────────
final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, double>((ref) {
  return FontSizeNotifier();
});

class FontSizeNotifier extends StateNotifier<double> {
  FontSizeNotifier() : super(14.0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble('font_size') ?? 14.0;
  }

  Future<void> setSize(double size) async {
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }
}

// ─── Language Provider ──────────────────────────────────
final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('English') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('app_language') ?? 'English';
  }

  Future<void> setLanguage(String lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
  }
}
