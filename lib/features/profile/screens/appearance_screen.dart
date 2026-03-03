import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/settings_provider.dart';

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final currentBubble = ref.watch(bubbleStyleProvider);
    final currentFontSize = ref.watch(fontSizeProvider);

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Appearance', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
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
                // Theme section
                _sectionHeader('Theme'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ThemeCard(
                      label: 'Dark Ocean',
                      colors: [const Color(0xFF060D1A), const Color(0xFF0C4A6E)],
                      isSelected: currentTheme == 'dark_ocean',
                      onTap: () => ref.read(themeProvider.notifier).setTheme('dark_ocean'),
                    ),
                    const SizedBox(width: 10),
                    _ThemeCard(
                      label: 'Light Glass',
                      colors: [const Color(0xFFE0F7FA), const Color(0xFFB2EBF2)],
                      isSelected: currentTheme == 'light_glass',
                      onTap: () => ref.read(themeProvider.notifier).setTheme('light_glass'),
                    ),
                    const SizedBox(width: 10),
                    _ThemeCard(
                      label: 'Midnight',
                      colors: [const Color(0xFF1A0033), const Color(0xFF4A0080)],
                      isSelected: currentTheme == 'midnight_purple',
                      onTap: () => ref.read(themeProvider.notifier).setTheme('midnight_purple'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bubble style section
                _sectionHeader('Chat Bubble Style'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _BubbleCard(
                      label: 'Rounded',
                      radius: 20,
                      isSelected: currentBubble == 'rounded',
                      onTap: () => ref.read(bubbleStyleProvider.notifier).setStyle('rounded'),
                    ),
                    const SizedBox(width: 10),
                    _BubbleCard(
                      label: 'Sharp',
                      radius: 4,
                      isSelected: currentBubble == 'sharp',
                      onTap: () => ref.read(bubbleStyleProvider.notifier).setStyle('sharp'),
                    ),
                    const SizedBox(width: 10),
                    _BubbleCard(
                      label: 'Minimal',
                      radius: 12,
                      isSelected: currentBubble == 'minimal',
                      onTap: () => ref.read(bubbleStyleProvider.notifier).setStyle('minimal'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Font size section
                _sectionHeader('Font Size'),
                const SizedBox(height: 8),
                GlassCard(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aa', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Text('Preview', style: TextStyle(color: Colors.white, fontSize: currentFontSize)),
                          Text('Aa', style: TextStyle(color: AppColors.textMuted, fontSize: 18)),
                        ],
                      ),
                      Slider(
                        value: currentFontSize,
                        min: 12,
                        max: 18,
                        divisions: 3,
                        label: _fontLabel(currentFontSize),
                        activeColor: AppColors.aquaCore,
                        inactiveColor: AppColors.glassPanel,
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

  Widget _sectionHeader(String title) => Text(
    title.toUpperCase(),
    style: AppTextStyles.caption.copyWith(
      fontSize: 11, fontWeight: FontWeight.w600,
      letterSpacing: 1.2, color: AppColors.aquaCore.withValues(alpha: 0.7),
    ),
  );
}

class _ThemeCard extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label, required this.colors,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                      ? Border.all(color: AppColors.aquaCore, width: 2)
                      : null,
                ),
                child: isSelected
                    ? const Center(child: Icon(Icons.check_circle_rounded,
                        color: AppColors.aquaCore, size: 24))
                    : null,
              ),
              const SizedBox(height: 6),
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleCard extends StatelessWidget {
  final String label;
  final double radius;
  final bool isSelected;
  final VoidCallback onTap;

  const _BubbleCard({
    required this.label, required this.radius,
    required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.aquaCore.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(radius),
                  border: isSelected
                      ? Border.all(color: AppColors.aquaCore, width: 2)
                      : null,
                ),
                child: Text('Hello!', style: AppTextStyles.caption.copyWith(
                    color: Colors.white, fontSize: 11)),
              ),
              const SizedBox(height: 6),
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
