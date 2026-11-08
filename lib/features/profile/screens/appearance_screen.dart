import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_models.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/settings_provider.dart';

/// Ultra-Modern, Redesigned Theme & Appearance Studio
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBubble = ref.watch(bubbleStyleProvider);
    final currentFontSize = ref.watch(fontSizeProvider);
    final rippleTheme = ref.watch(rippleThemeProvider);
    final isDark = rippleTheme.isDark;

    final textColor = rippleTheme.colors.textPrimary;
    final textMuted = rippleTheme.colors.textMuted;
    final primary = rippleTheme.colors.primary;
    final surfaceColor = rippleTheme.colors.surface;
    final cardBorder = rippleTheme.colors.glassBorder;

    return Scaffold(
      backgroundColor: rippleTheme.colors.background,
      appBar: AppBar(
        title: Text(
          L10n.s(ref, 'appearance'),
          style: AppTextStyles.heading.copyWith(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 380),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 30,
                curve: Curves.easeOutCubic,
                child: FadeInAnimation(child: w),
              ),
              children: [
                // 1. Live Interactive Simulated Chat Preview Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: isDark ? 0.2 : 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: rippleTheme.gradients.primary,
                              shape: BoxShape.circle,
                              boxShadow: rippleTheme.shadows.primaryGlow,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rippleTheme.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rippleTheme.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Color Swatches
                          Row(
                            children: [
                              _swatch(rippleTheme.colors.primary),
                              const SizedBox(width: 5),
                              _swatch(rippleTheme.colors.surface),
                              const SizedBox(width: 5),
                              _swatch(rippleTheme.colors.bubbleOutgoing),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Simulated Incoming Bubble
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 240),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: rippleTheme.colors.bubbleIncoming,
                            borderRadius: _bubbleRadius(currentBubble, isIncoming: true),
                            border: Border.all(color: cardBorder.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Text(
                            'Ripple zero-trace UI preview ✨',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                              fontSize: currentFontSize - 1,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Simulated Outgoing Bubble
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 240),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: rippleTheme.gradients.primary,
                            borderRadius: _bubbleRadius(currentBubble, isIncoming: false),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Sleek, fluid & fast. 🚀',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: currentFontSize - 1,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 2. Select Theme Gallery (Modern Grid)
                _sectionHeader(Icons.palette_rounded, 'THEME PALETTES', primary),
                const SizedBox(height: 12),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: ThemePresets.all.length,
                  itemBuilder: (context, index) {
                    final theme = ThemePresets.all[index];
                    final isSelected = theme.id == rippleTheme.id;

                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selectionTick();
                        ref.read(rippleThemeProvider.notifier).setTheme(theme.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primary.withValues(alpha: isDark ? 0.15 : 0.08)
                              : surfaceColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? primary : cardBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.22),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    gradient: theme.gradients.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.5),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      theme.isDark ? 'Dark' : 'Light',
                                      style: TextStyle(
                                        color: textMuted,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  theme.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                // 3. Chat Bubble Corner Geometry
                _sectionHeader(Icons.chat_bubble_rounded, 'MESSAGE BUBBLE GEOMETRY', primary),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _BubbleStyleCard(
                      label: 'Rounded Modern',
                      radius: 20,
                      isSelected: currentBubble == 'rounded',
                      onTap: () {
                        AppHaptics.lightTap();
                        ref.read(bubbleStyleProvider.notifier).setStyle('rounded');
                      },
                    ),
                    const SizedBox(width: 10),
                    _BubbleStyleCard(
                      label: 'Minimal Sleek',
                      radius: 12,
                      isSelected: currentBubble == 'minimal',
                      onTap: () {
                        AppHaptics.lightTap();
                        ref.read(bubbleStyleProvider.notifier).setStyle('minimal');
                      },
                    ),
                    const SizedBox(width: 10),
                    _BubbleStyleCard(
                      label: 'Geometric Sharp',
                      radius: 4,
                      isSelected: currentBubble == 'sharp',
                      onTap: () {
                        AppHaptics.lightTap();
                        ref.read(bubbleStyleProvider.notifier).setStyle('sharp');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 4. Fluid Typography Scale Slider
                _sectionHeader(Icons.format_size_rounded, 'TYPOGRAPHY & READING SCALE', primary),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aa', style: TextStyle(color: textMuted, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _fontLabel(currentFontSize),
                              style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          Text('Aa', style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: primary,
                          inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          thumbColor: primary,
                          overlayColor: primary.withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: currentFontSize,
                          min: 12,
                          max: 18,
                          divisions: 3,
                          onChanged: (v) {
                            AppHaptics.selectionTick();
                            ref.read(fontSizeProvider.notifier).setSize(v);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: ['Small (12px)', 'Default (14px)', 'Large (16px)', 'XL (18px)']
                            .map((l) => Text(l, style: TextStyle(color: textMuted, fontSize: 10)))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static BorderRadius _bubbleRadius(String style, {required bool isIncoming}) {
    double r = 20;
    if (style == 'sharp') r = 4;
    if (style == 'minimal') r = 12;

    if (isIncoming) {
      return BorderRadius.only(
        topLeft: Radius.circular(r),
        topRight: Radius.circular(r),
        bottomRight: Radius.circular(r),
        bottomLeft: const Radius.circular(4),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(r),
        topRight: Radius.circular(r),
        bottomLeft: Radius.circular(r),
        bottomRight: const Radius.circular(4),
      );
    }
  }

  static String _fontLabel(double size) {
    if (size <= 12) return 'Small (12px)';
    if (size <= 14) return 'Medium (14px)';
    if (size <= 16) return 'Large (16px)';
    return 'Extra Large (18px)';
  }

  static Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ],
    );
  }

  static Widget _swatch(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
      ),
    );
  }
}

class _BubbleStyleCard extends ConsumerWidget {
  final String label;
  final double radius;
  final bool isSelected;
  final VoidCallback onTap;

  const _BubbleStyleCard({
    required this.label,
    required this.radius,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final primary = theme.colors.primary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: isDark ? 0.15 : 0.08)
                : theme.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primary : theme.colors.glassBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Text(
                  'Aa',
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? primary : theme.colors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
