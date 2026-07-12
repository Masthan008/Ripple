import 'package:flutter/material.dart';

/// Theme data model for Ripple bioluminescent themes
class RippleTheme {
  final String id;
  final String name;
  final String description;
  final ThemeColors colors;
  final ThemeGradients gradients;
  final ThemeShadows shadows;
  final bool isDark;
  final String previewImage;

  const RippleTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.colors,
    required this.gradients,
    required this.shadows,
    this.isDark = true,
    this.previewImage = '',
  });
}

/// Color palette for a theme
class ThemeColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color error;
  final Color warning;
  final Color online;
  final Color glassBorder;
  final Color glassSurface;
  final Color bubbleIncoming;
  final Color bubbleOutgoing;

  const ThemeColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.error,
    required this.warning,
    required this.online,
    required this.glassBorder,
    required this.glassSurface,
    required this.bubbleIncoming,
    required this.bubbleOutgoing,
  });
}

/// Gradient definitions for a theme
class ThemeGradients {
  final LinearGradient primary;
  final LinearGradient surface;
  final LinearGradient bubbleOutgoing;
  final LinearGradient shimmer;
  final LinearGradient glass;

  const ThemeGradients({
    required this.primary,
    required this.surface,
    required this.bubbleOutgoing,
    required this.shimmer,
    required this.glass,
  });
}

/// Shadow/glow definitions for a theme
class ThemeShadows {
  final List<BoxShadow> primaryGlow;
  final List<BoxShadow> secondaryGlow;
  final List<BoxShadow> accentGlow;
  final List<BoxShadow> soft;

  const ThemeShadows({
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.accentGlow,
    required this.soft,
  });
}

/// Theme presets - Bioluminescent variations
class ThemePresets {
  ThemePresets._();

  // ═══════════════════════════════════════════════════════════════════
  // AQUA OCEAN (Default) - Deep sea bioluminescence
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme aquaOcean = RippleTheme(
    id: 'aqua_ocean',
    name: 'Aqua Ocean',
    description: 'Deep sea bioluminescence with cyan glow',
    isDark: true,
    colors: const ThemeColors(
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF22D3EE),
      accent: Color(0xFF38BDF8),
      background: Color(0xFF060D1A),
      surface: Color(0xFF0A1628),
      surfaceHighlight: Color(0xFF0F2240),
      textPrimary: Colors.white,
      textSecondary: Color(0xCCFFFFFF),
      textMuted: Color(0x80FFFFFF),
      success: Color(0xFF4ADE80),
      error: Color(0xFFF87171),
      warning: Color(0xFFFBBF24),
      online: Color(0xFF4ADE80),
      glassBorder: Color(0x33FFFFFF),
      glassSurface: Color(0x1AFFFFFF),
      bubbleIncoming: Color(0x1AFFFFFF),
      bubbleOutgoing: Color(0x660EA5E9),
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [Color(0xFF0A1628), Color(0xFF060D1A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0x660EA5E9), Color(0x4D38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x2DFFFFFF), Colors.transparent, Color(0x1A0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFF0EA5E9).withOpacity(0.25),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFF22D3EE).withOpacity(0.35),
          blurRadius: 20,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFF38BDF8).withOpacity(0.4),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // MIDNIGHT PURPLE - Mystic abyss
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme midnightPurple = RippleTheme(
    id: 'midnight_purple',
    name: 'Midnight Purple',
    description: 'Mystic abyss with violet bioluminescence',
    isDark: true,
    colors: const ThemeColors(
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFA78BFA),
      accent: Color(0xFFC4B5FD),
      background: Color(0xFF0D061A),
      surface: Color(0xFF1A0A28),
      surfaceHighlight: Color(0xFF280F40),
      textPrimary: Colors.white,
      textSecondary: Color(0xCCFFFFFF),
      textMuted: Color(0x80FFFFFF),
      success: Color(0xFF34D399),
      error: Color(0xFFF87171),
      warning: Color(0xFFFBBF24),
      online: Color(0xFF34D399),
      glassBorder: Color(0x33FFFFFF),
      glassSurface: Color(0x1AFFFFFF),
      bubbleIncoming: Color(0x1AFFFFFF),
      bubbleOutgoing: Color(0x668B5CF6),
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [Color(0xFF1A0A28), Color(0xFF0D061A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0x668B5CF6), Color(0x4DC4B5FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x2DFFFFFF), Colors.transparent, Color(0x1A8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFF8B5CF6).withOpacity(0.25),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFFA78BFA).withOpacity(0.35),
          blurRadius: 20,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFFC4B5FD).withOpacity(0.4),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // CORAL REEF - Warm underwater glow
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme coralReef = RippleTheme(
    id: 'coral_reef',
    name: 'Coral Reef',
    description: 'Warm coral tones with orange-pink glow',
    isDark: true,
    colors: const ThemeColors(
      primary: Color(0xFFEC4899),
      secondary: Color(0xFFF472B6),
      accent: Color(0xFFFB7185),
      background: Color(0xFF1A0D12),
      surface: Color(0xFF28141A),
      surfaceHighlight: Color(0xFF3D1F2A),
      textPrimary: Colors.white,
      textSecondary: Color(0xCCFFFFFF),
      textMuted: Color(0x80FFFFFF),
      success: Color(0xFF4ADE80),
      error: Color(0xFFF87171),
      warning: Color(0xFFFBBF24),
      online: Color(0xFF4ADE80),
      glassBorder: Color(0x33FFFFFF),
      glassSurface: Color(0x1AFFFFFF),
      bubbleIncoming: Color(0x1AFFFFFF),
      bubbleOutgoing: Color(0x66EC4899),
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFF472B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [Color(0xFF28141A), Color(0xFF1A0D12)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0x66EC4899), Color(0x4DFB7185)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x2DFFFFFF), Colors.transparent, Color(0x1AEC4899)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFFEC4899).withOpacity(0.25),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFFF472B6).withOpacity(0.35),
          blurRadius: 20,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFFFB7185).withOpacity(0.4),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // EMERALD DEPTH - Green bioluminescence
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme emeraldDepth = RippleTheme(
    id: 'emerald_depth',
    name: 'Emerald Depth',
    description: 'Deep emerald green bioluminescence',
    isDark: true,
    colors: const ThemeColors(
      primary: Color(0xFF10B981),
      secondary: Color(0xFF34D399),
      accent: Color(0xFF6EE7B7),
      background: Color(0xFF061A12),
      surface: Color(0xFF0A281C),
      surfaceHighlight: Color(0xFF0F4028),
      textPrimary: Colors.white,
      textSecondary: Color(0xCCFFFFFF),
      textMuted: Color(0x80FFFFFF),
      success: Color(0xFF4ADE80),
      error: Color(0xFFF87171),
      warning: Color(0xFFFBBF24),
      online: Color(0xFF4ADE80),
      glassBorder: Color(0x33FFFFFF),
      glassSurface: Color(0x1AFFFFFF),
      bubbleIncoming: Color(0x1AFFFFFF),
      bubbleOutgoing: Color(0x6610B981),
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF34D399)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [Color(0xFF0A281C), Color(0xFF061A12)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0x6610B981), Color(0x4D6EE7B7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x2DFFFFFF), Colors.transparent, Color(0x1A10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFF10B981).withOpacity(0.25),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFF34D399).withOpacity(0.35),
          blurRadius: 20,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFF6EE7B7).withOpacity(0.4),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // GOLDEN SAND - Warm beach sunset
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme goldenSand = RippleTheme(
    id: 'golden_sand',
    name: 'Golden Sand',
    description: 'Warm sunset amber and gold tones',
    isDark: true,
    colors: const ThemeColors(
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFBBF24),
      accent: Color(0xFFFCD34D),
      background: Color(0xFF1A1206),
      surface: Color(0xFF281D0A),
      surfaceHighlight: Color(0xFF402E0F),
      textPrimary: Colors.white,
      textSecondary: Color(0xCCFFFFFF),
      textMuted: Color(0x80FFFFFF),
      success: Color(0xFF4ADE80),
      error: Color(0xFFF87171),
      warning: Color(0xFFFBBF24),
      online: Color(0xFF4ADE80),
      glassBorder: Color(0x33FFFFFF),
      glassSurface: Color(0x1AFFFFFF),
      bubbleIncoming: Color(0x1AFFFFFF),
      bubbleOutgoing: Color(0x66F59E0B),
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [Color(0xFF281D0A), Color(0xFF1A1206)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0x66F59E0B), Color(0x4DFCD34D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x2DFFFFFF), Colors.transparent, Color(0x1AF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFFF59E0B).withOpacity(0.25),
          blurRadius: 24,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFFFBBF24).withOpacity(0.35),
          blurRadius: 20,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFFFCD34D).withOpacity(0.4),
          blurRadius: 32,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // CRYSTAL WATER - Light themed liquid glass
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme crystalWater = RippleTheme(
    id: 'crystal_water',
    name: 'Crystal Water',
    description: 'Clear, fluid light theme with icy cyan highlights',
    isDark: false,
    colors: const ThemeColors(
      primary: Color(0xFF0EA5E9),
      secondary: Color(0xFF38BDF8),
      accent: Color(0xFF7DD3FC),
      background: Color(0xFFF8FAFC),
      surface: Color(0xFFFFFFFF),
      surfaceHighlight: Color(0xFFF1F5F9),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF334155),
      textMuted: Color(0xFF64748B),
      success: Color(0xFF22C55E),
      error: Color(0xFFEF4444),
      warning: Color(0xFFF59E0B),
      online: Color(0xFF22C55E),
      glassBorder: Color(0x330EA5E9), // Light blue tint
      glassSurface: Color(0x80FFFFFF), // More opaque white for light theme
      bubbleIncoming: Color(0xE6FFFFFF),
      bubbleOutgoing: Color(0xE6E0F2FE), // Very light blue
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x2D0EA5E9), Colors.transparent, Color(0x1A0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.9),
          Colors.white.withOpacity(0.7),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFF0EA5E9).withOpacity(0.15),
          blurRadius: 20,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFF38BDF8).withOpacity(0.20),
          blurRadius: 16,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFF7DD3FC).withOpacity(0.25),
          blurRadius: 24,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: const Color(0xFFCBD5E1).withOpacity(0.4),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // iOS 27 - Light themed liquid glass with white light & water droplets
  // ═══════════════════════════════════════════════════════════════════
  static final RippleTheme ios27 = RippleTheme(
    id: 'ios_27',
    name: 'iOS 27',
    description: 'Liquid glass with glossy white light & water droplets',
    isDark: false,
    colors: const ThemeColors(
      primary: Color(0xFF007AFF), // Classic iOS Blue
      secondary: Color(0xFF5856D6), // iOS Indigo
      accent: Color(0xFF30D158), // iOS Green
      background: Color(0xFFEBEFF5), // Soft pastel lavender-blue base instead of pure white
      surface: Color(0xFFF2F5FA), // iOS System Light Grey
      surfaceHighlight: Color(0xFFE5E5EA),
      textPrimary: Color(0xFF1C1C1E), // Light-mode deep grey
      textSecondary: Color(0xFF3A3A3C),
      textMuted: Color(0xFF8E8E93),
      success: Color(0xFF34C759),
      error: Color(0xFFFF3B30),
      warning: Color(0xFFFF9500),
      online: Color(0xFF34C759),
      glassBorder: Color(0x3D8E8E93), // Slightly more distinct border
      glassSurface: Color(0xA0FFFFFF), // Glossy semi-transparent white glass
      bubbleIncoming: Color(0xFFE5E5EA),
      bubbleOutgoing: Color(0xFF007AFF),
    ),
    gradients: ThemeGradients(
      primary: const LinearGradient(
        colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      surface: const LinearGradient(
        colors: [
          Color(0xFFE6F0FA), // Soft sky blue
          Color(0xFFF5E6FA), // Soft lavender
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      bubbleOutgoing: const LinearGradient(
        colors: [Color(0xFF007AFF), Color(0xFF0A84FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shimmer: const LinearGradient(
        colors: [Color(0x33FFFFFF), Colors.transparent, Color(0x1A007AFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      glass: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.95),
          Colors.white.withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    shadows: ThemeShadows(
      primaryGlow: [
        BoxShadow(
          color: const Color(0xFF007AFF).withOpacity(0.12), // Subtle blue glow
          blurRadius: 20,
          spreadRadius: -2,
        ),
      ],
      secondaryGlow: [
        BoxShadow(
          color: const Color(0xFF5856D6).withOpacity(0.10), // Subtle purple glow
          blurRadius: 16,
          spreadRadius: -1,
        ),
      ],
      accentGlow: [
        BoxShadow(
          color: const Color(0xFF30D158).withOpacity(0.15),
          blurRadius: 24,
          spreadRadius: 2,
        ),
      ],
      soft: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ],
    ),
  );

  // ═══════════════════════════════════════════════════════════════════
  // GET ALL THEMES
  // ═══════════════════════════════════════════════════════════════════
  static List<RippleTheme> get all => [
    aquaOcean,
    midnightPurple,
    coralReef,
    emeraldDepth,
    goldenSand,
    crystalWater,
    ios27,
  ];

  static RippleTheme getById(String id) {
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => aquaOcean,
    );
  }
}
