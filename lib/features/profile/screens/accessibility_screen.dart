import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/accessibility_provider.dart';

/// Accessibility settings screen
/// High contrast, reduced motion, larger text options
class AccessibilityScreen extends ConsumerWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Accessibility',
          style: TextStyle(
            color: theme.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Reset button
          TextButton(
            onPressed: () {
              _showResetDialog(context, ref);
            },
            child: Text(
              'Reset',
              style: TextStyle(color: theme.colors.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active features status banner
          _buildStatusBanner(ref, accessibility),
          const SizedBox(height: 16),

          // Visual section
          _sectionHeader('Visual', theme.colors.primary),
          const SizedBox(height: 12),

          // High Contrast
          _buildToggleCard(
            context,
            ref,
            icon: Icons.contrast,
            title: 'High Contrast',
            subtitle: 'Increase contrast for better visibility',
            value: accessibility.highContrast,
            onToggle: (value) {
              ref.read(accessibilityProvider.notifier).toggleHighContrast(value);
            },
          ),

          const SizedBox(height: 12),

          // Larger Text
          _buildToggleCard(
            context,
            ref,
            icon: Icons.format_size,
            title: 'Larger Text',
            subtitle: 'Increase text size throughout the app',
            value: accessibility.largerText,
            onToggle: (value) {
              ref.read(accessibilityProvider.notifier).toggleLargerText(value);
            },
          ),

          const SizedBox(height: 12),

          // Color Blind Mode
          _buildToggleCard(
            context,
            ref,
            icon: Icons.color_lens,
            title: 'Color Blind Friendly',
            subtitle: 'Use patterns and labels instead of color alone',
            value: accessibility.colorBlindMode,
            onToggle: (value) {
              ref.read(accessibilityProvider.notifier).toggleColorBlindMode(value);
            },
          ),

          const SizedBox(height: 24),

          // Motion section
          _sectionHeader('Motion', theme.colors.primary),
          const SizedBox(height: 12),

          // Reduced Motion
          _buildToggleCard(
            context,
            ref,
            icon: Icons.animation,
            title: 'Reduced Motion',
            subtitle: 'Minimize animations and transitions',
            value: accessibility.reducedMotion,
            onToggle: (value) {
              ref.read(accessibilityProvider.notifier).toggleReducedMotion(value);
            },
          ),

          const SizedBox(height: 12),

          // Haptic Feedback
          _buildToggleCard(
            context,
            ref,
            icon: Icons.vibration,
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on button presses and interactions',
            value: !accessibility.reducedMotion,
            onToggle: (value) {
              // Haptic is inversely tied to reduced motion for now
            },
          ),

          const SizedBox(height: 24),

          // Screen Reader section
          _sectionHeader('Screen Reader', theme.colors.primary),
          const SizedBox(height: 12),

          // Screen Reader Optimized
          _buildToggleCard(
            context,
            ref,
            icon: Icons.record_voice_over,
            title: 'Screen Reader Optimized',
            subtitle: 'Enhanced labels and descriptions for voice over',
            value: accessibility.screenReaderOptimized,
            onToggle: (value) {
              ref.read(accessibilityProvider.notifier).toggleScreenReaderOptimized(value);
            },
          ),

          const SizedBox(height: 24),

          // Text Scale Slider
          _sectionHeader('Text Size Scale', theme.colors.primary),
          const SizedBox(height: 12),

          GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'A',
                      style: TextStyle(
                        color: theme.colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: accessibility.textScale,
                        min: 0.8,
                        max: 1.5,
                        divisions: 7,
                        activeColor: theme.colors.primary,
                        inactiveColor: theme.colors.glassBorder,
                        onChanged: (value) {
                          ref.read(accessibilityProvider.notifier).setTextScale(value);
                        },
                      ),
                    ),
                    Text(
                      'A',
                      style: TextStyle(
                        color: theme.colors.textMuted,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Current scale: ${(accessibility.textScale * 100).toInt()}%',
                  style: TextStyle(
                    color: theme.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Preview section
          _sectionHeader('Preview', theme.colors.primary),
          const SizedBox(height: 12),

          _buildPreviewCard(context, ref),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(WidgetRef ref, AccessibilitySettings accessibility) {
    final theme = ref.watch(rippleThemeProvider);
    final activeCount = [
      accessibility.highContrast,
      accessibility.reducedMotion,
      accessibility.largerText,
      accessibility.screenReaderOptimized,
      accessibility.colorBlindMode,
      accessibility.textScale != 1.0,
    ].where((v) => v).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: activeCount > 0
            ? LinearGradient(
                colors: [
                  theme.colors.primary.withOpacity(0.15),
                  theme.colors.primary.withOpacity(0.05),
                ],
              )
            : null,
        color: activeCount == 0 ? theme.colors.glassSurface : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activeCount > 0
              ? theme.colors.primary.withOpacity(0.4)
              : theme.colors.glassBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: activeCount > 0 ? theme.gradients.primary : null,
              color: activeCount == 0 ? theme.colors.glassSurface : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              activeCount > 0 ? Icons.accessibility_new : Icons.accessibility_outlined,
              color: activeCount > 0 ? Colors.white : theme.colors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeCount > 0 ? '$activeCount feature${activeCount > 1 ? 's' : ''} active' : 'All defaults',
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeCount > 0 ? 'Accessibility settings are customized' : 'No accessibility adjustments applied',
                  style: TextStyle(
                    color: theme.colors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: theme.gradients.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ON',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleCard(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onToggle,
  }) {
    final theme = ref.watch(rippleThemeProvider);

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value 
                ? theme.colors.primary.withOpacity(0.2)
                : theme.colors.glassSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: value 
                  ? theme.colors.primary.withOpacity(0.5)
                  : theme.colors.glassBorder,
              ),
            ),
            child: Icon(
              icon,
              color: value ? theme.colors.primary : theme.colors.textMuted,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onToggle,
            activeColor: theme.colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final accessibility = ref.watch(accessibilityProvider);

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sample message bubble preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: accessibility.highContrast
                ? null
                : theme.gradients.primary,
              color: accessibility.highContrast ? Colors.cyan : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accessibility.highContrast
                  ? Colors.white
                  : theme.colors.primary.withOpacity(0.3),
              ),
            ),
            child: Text(
              'This is how messages will look',
              style: TextStyle(
                color: accessibility.highContrast ? Colors.black : Colors.white,
                fontSize: 14 * accessibility.textScale,
                fontWeight: accessibility.highContrast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Sample text preview
          Text(
            'Sample Text Preview',
            style: TextStyle(
              color: theme.colors.textPrimary,
              fontSize: 18 * accessibility.textScale,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'This shows how your text will appear with the current accessibility settings.',
            style: TextStyle(
              color: theme.colors.textSecondary,
              fontSize: 14 * accessibility.textScale,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    final theme = ref.read(rippleThemeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colors.glassBorder),
        ),
        title: Text(
          'Reset Accessibility Settings?',
          style: TextStyle(color: theme.colors.textPrimary),
        ),
        content: Text(
          'This will reset all accessibility settings to default values.',
          style: TextStyle(color: theme.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              // Reset all settings
              ref.read(accessibilityProvider.notifier)
                ..toggleHighContrast(false)
                ..toggleReducedMotion(false)
                ..toggleLargerText(false)
                ..toggleScreenReaderOptimized(false)
                ..toggleColorBlindMode(false)
                ..setTextScale(1.0);
              Navigator.pop(context);
            },
            child: Text(
              'Reset',
              style: TextStyle(color: theme.colors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
