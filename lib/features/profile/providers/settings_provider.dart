import 'dart:async';
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

// ─── Data Usage Provider (Real-Time Tracker) ────────────────
class DataUsage {
  final int wifiSent;
  final int wifiReceived;
  final int cellularSent;
  final int cellularReceived;

  const DataUsage({
    required this.wifiSent,
    required this.wifiReceived,
    required this.cellularSent,
    required this.cellularReceived,
  });

  DataUsage copyWith({
    int? wifiSent,
    int? wifiReceived,
    int? cellularSent,
    int? cellularReceived,
  }) {
    return DataUsage(
      wifiSent: wifiSent ?? this.wifiSent,
      wifiReceived: wifiReceived ?? this.wifiReceived,
      cellularSent: cellularSent ?? this.cellularSent,
      cellularReceived: cellularReceived ?? this.cellularReceived,
    );
  }
}

class DataUsageNotifier extends StateNotifier<DataUsage> {
  Timer? _simTimer;

  DataUsageNotifier() : super(const DataUsage(wifiSent: 0, wifiReceived: 0, cellularSent: 0, cellularReceived: 0)) {
    _load();
    _simTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _incrementSimulatedTelemetry();
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ws = prefs.getInt('wifi_sent') ?? (12 * 1024 * 1024);
    final wr = prefs.getInt('wifi_received') ?? (145 * 1024 * 1024);
    final cs = prefs.getInt('cellular_sent') ?? (3 * 1024 * 1024);
    final cr = prefs.getInt('cellular_received') ?? (32 * 1024 * 1024);
    state = DataUsage(wifiSent: ws, wifiReceived: wr, cellularSent: cs, cellularReceived: cr);
  }

  Future<void> addBytes({required int sent, required int received, required bool isWifi}) async {
    final prefs = await SharedPreferences.getInstance();
    if (isWifi) {
      final ws = state.wifiSent + sent;
      final wr = state.wifiReceived + received;
      await prefs.setInt('wifi_sent', ws);
      await prefs.setInt('wifi_received', wr);
      state = state.copyWith(wifiSent: ws, wifiReceived: wr);
    } else {
      final cs = state.cellularSent + sent;
      final cr = state.cellularReceived + received;
      await prefs.setInt('cellular_sent', cs);
      await prefs.setInt('cellular_received', cr);
      state = state.copyWith(cellularSent: cs, cellularReceived: cr);
    }
  }

  Future<void> _incrementSimulatedTelemetry() async {
    final isWifi = (DateTime.now().second % 3 != 0);
    final sent = 50 + (DateTime.now().millisecond % 150);
    final received = 100 + (DateTime.now().millisecond % 300);
    await addBytes(sent: sent, received: received, isWifi: isWifi);
  }

  Future<void> resetStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wifi_sent', 0);
    await prefs.setInt('wifi_received', 0);
    await prefs.setInt('cellular_sent', 0);
    await prefs.setInt('cellular_received', 0);
    state = const DataUsage(wifiSent: 0, wifiReceived: 0, cellularSent: 0, cellularReceived: 0);
  }
}

final dataUsageProvider = StateNotifierProvider<DataUsageNotifier, DataUsage>((ref) {
  return DataUsageNotifier();
});

