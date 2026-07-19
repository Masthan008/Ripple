import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/theme_glass_card.dart';
import '../providers/accessibility_provider.dart';

/// Upgraded & Interactive Accessibility Control Center
class AccessibilityScreen extends ConsumerStatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  ConsumerState<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends ConsumerState<AccessibilityScreen> {
  bool _isSpeakingDemo = false;

  void _testHapticFeedback() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚡ Haptic vibration feedback triggered!'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.aquaCore,
      ),
    );
  }

  void _testTextToSpeech() {
    setState(() => _isSpeakingDemo = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🗣️ Narrator: "Welcome to Ripple. Your accessible AI messaging companion."'),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF8B5CF6),
      ),
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isSpeakingDemo = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final accessibility = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: theme.colors.surface,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF10B981)]),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.accessibility_new_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Accessibility',
              style: TextStyle(
                color: theme.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _showResetDialog(context, notifier),
            child: const Text('Reset All', style: TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active features status banner
          _buildStatusBanner(accessibility),
          const SizedBox(height: 16),

          // Visual Section
          _sectionHeader('VISUAL ENHANCEMENTS', const Color(0xFF0EA5E9)),
          const SizedBox(height: 8),

          _buildToggleTile(
            icon: Icons.contrast_rounded,
            iconColor: const Color(0xFF0EA5E9),
            title: 'High Contrast Mode',
            subtitle: 'Enhance border visibility and text crispness across all screens',
            value: accessibility.highContrast,
            onChanged: notifier.toggleHighContrast,
          ),

          _buildToggleTile(
            icon: Icons.format_size_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: 'Larger Text (125%)',
            subtitle: 'Increase font sizes app-wide for comfortable reading',
            value: accessibility.largerText,
            onChanged: notifier.toggleLargerText,
          ),

          _buildToggleTile(
            icon: Icons.color_lens_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Color Blind Friendly Indicators',
            subtitle: 'Enhance status badges with distinct geometric shapes and symbols',
            value: accessibility.colorBlindMode,
            onChanged: notifier.toggleColorBlindMode,
          ),

          const SizedBox(height: 16),
          // Motion & Haptics Section
          _sectionHeader('MOTION & TOUCH HAPTICS', const Color(0xFFF59E0B)),
          const SizedBox(height: 8),

          _buildToggleTile(
            icon: Icons.animation_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Reduced Motion',
            subtitle: 'Minimize complex page transitions and fluid physics animations',
            value: accessibility.reducedMotion,
            onChanged: notifier.toggleReducedMotion,
          ),

          _buildToggleTile(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFFEC4899),
            title: 'Haptic Touch Feedback',
            subtitle: 'Tactile vibration cues when tapping buttons and sending messages',
            value: accessibility.hapticFeedback,
            onChanged: notifier.toggleHapticFeedback,
            onTest: _testHapticFeedback,
            testLabel: 'Test Vibration',
          ),

          _buildToggleTile(
            icon: Icons.ads_click_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Large Touch Targets',
            subtitle: 'Expand interactive button padding to at least 48dp for easy tapping',
            value: accessibility.largeTapTargets,
            onChanged: notifier.toggleLargeTapTargets,
          ),

          const SizedBox(height: 16),
          // Voice & Screen Reader Section
          _sectionHeader('SCREEN READER & VOICE NARRATION', const Color(0xFF8B5CF6)),
          const SizedBox(height: 8),

          _buildToggleTile(
            icon: Icons.record_voice_over_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Screen Reader Optimizations',
            subtitle: 'Detailed semantic descriptions for TalkBack and VoiceOver readers',
            value: accessibility.screenReaderOptimized,
            onChanged: notifier.toggleScreenReaderOptimized,
          ),

          _buildToggleTile(
            icon: Icons.volume_up_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: 'Text-to-Speech (TTS) Narrator',
            subtitle: 'Automatically read incoming messages aloud',
            value: accessibility.textToSpeech,
            onChanged: notifier.toggleTextToSpeech,
            onTest: _testTextToSpeech,
            testLabel: _isSpeakingDemo ? 'Speaking...' : 'Test Narrator',
          ),

          const SizedBox(height: 16),
          // Text Size Scale Slider
          _sectionHeader('DYNAMIC TEXT SCALE', const Color(0xFF14B8A6)),
          const SizedBox(height: 8),

          ThemeGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Text Scale Factor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.aquaCore.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${(accessibility.effectiveTextScale * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('A', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Slider(
                        value: accessibility.effectiveTextScale,
                        min: 0.85,
                        max: 1.40,
                        divisions: 11,
                        activeColor: AppColors.aquaCore,
                        inactiveColor: Colors.white12,
                        onChanged: (val) => notifier.setTextScale(val),
                      ),
                    ),
                    const Text('A', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          _sectionHeader('LIVE INTERACTIVE PREVIEW', const Color(0xFF3B82F6)),
          const SizedBox(height: 8),

          _buildLivePreviewCard(accessibility),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(AccessibilitySettings accessibility) {
    final activeCount = [
      accessibility.highContrast,
      accessibility.reducedMotion,
      accessibility.largerText,
      accessibility.screenReaderOptimized,
      accessibility.colorBlindMode,
      accessibility.textToSpeech,
      accessibility.largeTapTargets,
      accessibility.textScale != 1.0,
    ].where((v) => v).length;

    return ThemeGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: activeCount > 0
                  ? const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF10B981)])
                  : null,
              color: activeCount == 0 ? Colors.white10 : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              activeCount > 0 ? Icons.accessibility_new_rounded : Icons.accessibility_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeCount > 0 ? '$activeCount Feature${activeCount > 1 ? 's' : ''} Active' : 'Default Profile',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  activeCount > 0 ? 'Customized for inclusive accessibility' : 'Standard visual & motion settings',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        title,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTest,
    String? testLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ThemeGlassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.aquaCore,
                  activeTrackColor: const Color(0x550EA5E9),
                ),
              ],
            ),
            if (value && onTest != null) ...[
              const SizedBox(height: 6),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.play_arrow_rounded, size: 14, color: AppColors.aquaCore),
                  label: Text(testLabel ?? 'Test', style: const TextStyle(color: AppColors.aquaCore, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), minimumSize: Size.zero),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(AccessibilitySettings accessibility) {
    return ThemeGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bubble preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: accessibility.highContrast
                  ? null
                  : const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4)]),
              color: accessibility.highContrast ? Colors.cyan : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accessibility.highContrast ? Colors.white : Colors.transparent, width: 2),
            ),
            child: Text(
              'Sample Message Bubble',
              style: TextStyle(
                color: accessibility.highContrast ? Colors.black : Colors.white,
                fontSize: 14 * accessibility.effectiveTextScale,
                fontWeight: accessibility.highContrast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Live Screen Contrast & Scale',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16 * accessibility.effectiveTextScale,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This box dynamically previews font scale, text weight, contrast ratios, and color adjustments in real time.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12 * accessibility.effectiveTextScale,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, AccessibilityNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.aquaCore)),
        title: const Text('Reset Accessibility Settings?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('This will reset all font scales, contrast adjustments, and narrator settings to standard defaults.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              notifier.resetAll();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaCore, foregroundColor: Colors.black),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
