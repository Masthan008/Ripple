import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_models.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/smart_theme_switcher.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/settings_provider.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final currentBubble = ref.watch(bubbleStyleProvider);
    final currentFontSize = ref.watch(fontSizeProvider);
    final rippleTheme = ref.watch(rippleThemeProvider);

    return Scaffold(
      backgroundColor: rippleTheme.colors.background,
      appBar: AppBar(
        title: Text(L10n.s(ref, 'appearance'), style: AppTextStyles.heading.copyWith(
          color: rippleTheme.colors.textPrimary,
        )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: rippleTheme.colors.primary),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 50, curve: Curves.easeOutBack,
                child: FadeInAnimation(child: w),
              ),
              children: [
                // Live Theme Preview Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: rippleTheme.gradients.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: rippleTheme.colors.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: rippleTheme.shadows.primaryGlow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: rippleTheme.gradients.primary,
                              shape: BoxShape.circle,
                              boxShadow: rippleTheme.shadows.primaryGlow,
                            ),
                            child: const Icon(Icons.palette_outlined, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rippleTheme.name,
                                  style: TextStyle(
                                    color: rippleTheme.colors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Active Theme',
                                  style: TextStyle(
                                    color: rippleTheme.colors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Color swatches
                          Row(
                            children: [
                              _colorDot(rippleTheme.colors.primary),
                              const SizedBox(width: 4),
                              _colorDot(rippleTheme.colors.surface),
                              const SizedBox(width: 4),
                              _colorDot(rippleTheme.colors.background),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Mini chat bubble preview
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: rippleTheme.gradients.primary,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(4),
                                ),
                              ),
                              child: const Text(
                                'Hey! Look at this theme ✨',
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 50),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 50),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: rippleTheme.colors.glassSurface,
                                border: Border.all(color: rippleTheme.colors.glassBorder),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                'Looks amazing! 💙',
                                style: TextStyle(
                                  color: rippleTheme.colors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ORIGINAL 3 Themes (now mapped to Ripple Themes)
                _sectionHeaderWithIcon(Icons.auto_awesome_outlined, 'Classic Themes', rippleTheme.colors.primary.withOpacity(0.7)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ThemeCard(
                      label: L10n.s(ref, 'darkOcean'),
                      colors: [const Color(0xFF060D1A), const Color(0xFF0C4A6E)],
                      isSelected: rippleTheme.id == 'aqua_ocean',
                      accentColor: rippleTheme.colors.primary,
                      onTap: () {
                        ref.read(rippleThemeProvider.notifier).setTheme('aqua_ocean');
                        ref.read(themeProvider.notifier).setTheme('dark_ocean');
                      },
                    ),
                    const SizedBox(width: 10),
                    _ThemeCard(
                      label: L10n.s(ref, 'lightGlass'),
                      colors: [const Color(0xFFE0F7FA), const Color(0xFFB2EBF2)],
                      isSelected: rippleTheme.id == 'crystal_water',
                      accentColor: rippleTheme.colors.primary,
                      onTap: () {
                        ref.read(rippleThemeProvider.notifier).setTheme('crystal_water');
                        ref.read(themeProvider.notifier).setTheme('light_glass');
                      },
                    ),
                    const SizedBox(width: 10),
                    _ThemeCard(
                      label: L10n.s(ref, 'midnight'),
                      colors: [const Color(0xFF1A0033), const Color(0xFF4A0080)],
                      isSelected: rippleTheme.id == 'midnight_purple',
                      accentColor: rippleTheme.colors.primary,
                      onTap: () {
                        ref.read(rippleThemeProvider.notifier).setTheme('midnight_purple');
                        ref.read(themeProvider.notifier).setTheme('midnight_purple');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // NEW Bioluminescent & Liquid Themes
                _sectionHeaderWithIcon(Icons.water_drop_outlined, 'Bioluminescent & Liquid', rippleTheme.colors.primary.withOpacity(0.7)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: ThemePresets.all.length,
                    itemBuilder: (context, index) {
                      final theme = ThemePresets.all[index];
                      final isSelected = theme.id == rippleTheme.id;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => ref.read(rippleThemeProvider.notifier).setTheme(theme.id),
                          child: Container(
                            width: 110,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: theme.gradients.surface,
                              border: Border.all(
                                color: isSelected ? theme.colors.primary : rippleTheme.colors.glassBorder,
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected ? theme.shadows.primaryGlow : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: theme.gradients.primary,
                                    boxShadow: theme.shadows.primaryGlow,
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  theme.name,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    color: isSelected ? theme.colors.primary : (theme.isDark ? Colors.white : Colors.black87),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Smart Theme Switcher section
                _sectionHeaderWithIcon(Icons.auto_mode_outlined, 'Smart Theme Switcher', rippleTheme.colors.primary.withOpacity(0.7)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => const SmartThemeSettingsSheet(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rippleTheme.colors.glassSurface,
                          rippleTheme.colors.surface.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: rippleTheme.colors.glassBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: rippleTheme.gradients.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto Theme Switching',
                                style: TextStyle(
                                  color: rippleTheme.colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Themes change based on time of day',
                                style: TextStyle(
                                  color: rippleTheme.colors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: rippleTheme.colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Bubble style section
                _sectionHeaderWithIcon(Icons.chat_bubble_outline_rounded, L10n.s(ref, 'chatBubbleStyle'), rippleTheme.colors.primary.withOpacity(0.7)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BubbleCard(
                      label: L10n.s(ref, 'rounded'),
                      radius: 20,
                      isSelected: currentBubble == 'rounded',
                      onTap: () => ref.read(bubbleStyleProvider.notifier).setStyle('rounded'),
                    ),
                    const SizedBox(width: 10),
                    _BubbleCard(
                      label: L10n.s(ref, 'sharp'),
                      radius: 4,
                      isSelected: currentBubble == 'sharp',
                      onTap: () => ref.read(bubbleStyleProvider.notifier).setStyle('sharp'),
                    ),
                    const SizedBox(width: 10),
                    _BubbleCard(
                      label: L10n.s(ref, 'minimal'),
                      radius: 12,
                      isSelected: currentBubble == 'minimal',
                      onTap: () => ref.read(bubbleStyleProvider.notifier).setStyle('minimal'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Font size section
                _sectionHeaderWithIcon(Icons.text_fields_rounded, L10n.s(ref, 'fontSize'), rippleTheme.colors.primary.withOpacity(0.7)),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aa', style: TextStyle(color: rippleTheme.colors.textMuted, fontSize: 12)),
                          Text('Preview', style: TextStyle(color: rippleTheme.colors.textPrimary, fontSize: currentFontSize)),
                          Text('Aa', style: TextStyle(color: rippleTheme.colors.textMuted, fontSize: 18)),
                        ],
                      ),
                      Slider(
                        value: currentFontSize,
                        min: 12,
                        max: 18,
                        divisions: 3,
                        label: _fontLabel(currentFontSize),
                        activeColor: rippleTheme.colors.primary,
                        inactiveColor: rippleTheme.colors.glassSurface,
                        onChanged: (v) => ref.read(fontSizeProvider.notifier).setSize(v),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['Small', 'Medium', 'Large', 'XL']
                            .map((l) => Text(l, style: AppTextStyles.caption.copyWith(fontSize: 10)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fontLabel(double size) {
    if (size <= 12) return 'Small';
    if (size <= 14) return 'Medium';
    if (size <= 16) return 'Large';
    return 'XL';
  }

  Widget _sectionHeaderWithIcon(IconData icon, String title, Color color) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 11, fontWeight: FontWeight.w600,
          letterSpacing: 1.2, color: color,
        ),
      ),
    ],
  );

  Widget _colorDot(Color color) => Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24, width: 1),
    ),
  );
}

class _ThemeCard extends ConsumerWidget {
  final String label;
  final List<Color> colors;
  final bool isSelected;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label, required this.colors,
    required this.isSelected, required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final accent = accentColor ?? theme.colors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: accent, width: 2)
                      : null,
                ),
                child: isSelected
                    ? Center(child: Icon(Icons.check_circle_rounded,
                        color: accent, size: 24))
                    : null,
              ),
              const SizedBox(height: 6),
              Text(label, style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: theme.colors.textSecondary,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleCard extends ConsumerWidget {
  final String label;
  final double radius;
  final bool isSelected;
  final VoidCallback onTap;

  const _BubbleCard({
    required this.label, required this.radius,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(radius),
                  border: isSelected
                      ? Border.all(color: theme.colors.primary, width: 2)
                      : null,
                ),
                child: Text('Hello!', style: AppTextStyles.caption.copyWith(
                    color: theme.colors.textPrimary, fontSize: 11)),
              ),
              const SizedBox(height: 6),
              Text(label, style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: theme.colors.textSecondary,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
