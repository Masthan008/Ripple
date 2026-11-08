import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/haptic_feedback.dart';

/// Release Highlights & "What's New" Changelog Screen
class WhatsNewScreen extends ConsumerWidget {
  const WhatsNewScreen({super.key});

  static const String currentAppVersion = '1.0.4+47';
  static const String prefKeyLastVersion = 'ripple_last_seen_whats_new_version';

  /// Automatically displays What's New modal sheet on first launch of a new version
  static Future<void> showIfVersionUpdated(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(prefKeyLastVersion);
      if (lastSeen != currentAppVersion) {
        if (!context.mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const WhatsNewModalSheet(),
        );
        await prefs.setString(prefKeyLastVersion, currentAppVersion);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final textColor = theme.colors.textPrimary;
    final textMuted = theme.colors.textMuted;
    final primary = theme.colors.primary;
    final surfaceColor = theme.colors.surface;
    final cardBorder = theme.colors.glassBorder;

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(
          "What's New",
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
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 380),
            childAnimationBuilder: (w) => SlideAnimation(
              verticalOffset: 30,
              curve: Curves.easeOutCubic,
              child: FadeInAnimation(child: w),
            ),
            children: [
              // Hero Release Banner
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primary.withValues(alpha: 0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: isDark ? 0.18 : 0.08),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                          ),
                          child: const Text(
                            'LATEST RELEASE',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'v1.0.4 • Build 47',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ripple Sovereign All-Access',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Freemium paywalls eliminated. Unlimited cloud storage for all users, restored Stealth Vault, brand-new appearance studio, WhatsApp-grade push notifications & AI status creator.',
                      style: TextStyle(color: textMuted, fontSize: 13, height: 1.45),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _sectionTitle('RELEASE HIGHLIGHTS', primary),
              const SizedBox(height: 12),

              _buildReleaseCard(
                category: 'ALL-ACCESS',
                categoryColor: const Color(0xFF10B981),
                title: '100% Free Sovereign Access',
                description: 'All subscription locks, freemium barriers, and cloud storage limits have been completely removed. Verified trust badges, 4K media sharing, and custom dynamic styling are now complimentary for every user.',
                icon: Icons.lock_open_rounded,
                surfaceColor: surfaceColor,
                cardBorder: cardBorder,
                textColor: textColor,
                textMuted: textMuted,
              ),

              const SizedBox(height: 12),

              _buildReleaseCard(
                category: 'SECURITY',
                categoryColor: const Color(0xFF0EA5E9),
                title: 'Stealth Vault Restored & Dial Code Search',
                description: 'Fixed hidden conversation routing and message rendering. You can now type your secret dial code (e.g. *7777#) in the chat search bar to reveal your isolated vault with zero trace.',
                icon: Icons.shield_rounded,
                surfaceColor: surfaceColor,
                cardBorder: cardBorder,
                textColor: textColor,
                textMuted: textMuted,
              ),

              const SizedBox(height: 12),

              _buildReleaseCard(
                category: 'APPEARANCE',
                categoryColor: const Color(0xFF8B5CF6),
                title: 'Vercel Light & OLED Obsidian Themes',
                description: 'Removed legacy ocean views and crystal water themes. Added clean, high-contrast monochrome Vercel Light and true black OLED Obsidian with live interactive message preview.',
                icon: Icons.palette_rounded,
                surfaceColor: surfaceColor,
                cardBorder: cardBorder,
                textColor: textColor,
                textMuted: textMuted,
              ),

              const SizedBox(height: 12),

              _buildReleaseCard(
                category: 'NOTIFICATIONS',
                categoryColor: const Color(0xFFF59E0B),
                title: 'WhatsApp-Grade Rich Push Notifications',
                description: 'Full background and lock-screen push alerts with sender profile photos, direct quick reply, real-time unread badges, full-screen incoming call banners, and status reaction alerts.',
                icon: Icons.notifications_active_rounded,
                surfaceColor: surfaceColor,
                cardBorder: cardBorder,
                textColor: textColor,
                textMuted: textMuted,
              ),

              const SizedBox(height: 12),

              _buildReleaseCard(
                category: 'STATUS STUDIO',
                categoryColor: const Color(0xFFEC4899),
                title: 'AI Status Studio & Creative Visual Filters',
                description: 'Create aesthetic photo and quote updates using instant AI caption & image generation. Replaced ocean effects with Cyberpunk Neon, Golden Hour, Chromatic Glow, Retro Film, and Aurora Shimmer.',
                icon: Icons.auto_awesome_rounded,
                surfaceColor: surfaceColor,
                cardBorder: cardBorder,
                textColor: textColor,
                textMuted: textMuted,
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sectionTitle(String text, Color color) {
    return Row(
      children: [
        Icon(Icons.bolt_rounded, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  static Widget _buildReleaseCard({
    required String category,
    required Color categoryColor,
    required String title,
    required String description,
    required IconData icon,
    required Color surfaceColor,
    required Color cardBorder,
    required Color textColor,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: categoryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: categoryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: textMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet Presentation of What's New
class WhatsNewModalSheet extends ConsumerWidget {
  const WhatsNewModalSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;
    final textColor = theme.colors.textPrimary;
    final textMuted = theme.colors.textMuted;
    final primary = theme.colors.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: theme.colors.glassBorder, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.rocket_launch_rounded, color: primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New in Ripple",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Version 1.0.4 (Build 47)',
                        style: TextStyle(color: textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _featureRow(
                  icon: Icons.lock_open_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: '100% Free Sovereign Access',
                  desc: 'All freemium paywalls eliminated. Unlimited cloud storage, verified badges, and 4K media free for all.',
                  textColor: textColor,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 16),
                _featureRow(
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'Stealth Vault Restored & Secret Dial Code',
                  desc: 'Moved conversations can be viewed, chatted with, and opened directly. Dial *7777# in chat search to unlock.',
                  textColor: textColor,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 16),
                _featureRow(
                  icon: Icons.palette_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Vercel Light & OLED Obsidian Themes',
                  desc: 'Removed legacy ocean/crystal themes. Fresh modern UI with live simulated preview and fluid animations.',
                  textColor: textColor,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 16),
                _featureRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'WhatsApp-Grade High-Priority Push Alerts',
                  desc: 'Reliable background notifications with profile avatars, direct quick reply, and live call alert banners.',
                  textColor: textColor,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 16),
                _featureRow(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFEC4899),
                  title: 'AI Status Studio & Creative Visual Effects',
                  desc: 'Instant AI caption and image creator with modern Cyberpunk, Golden Hour, Chromatic, and Retro filters.',
                  textColor: textColor,
                  textMuted: textMuted,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () {
                  AppHaptics.selectionTick();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Explore Ripple v1.0.4',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required Color textColor,
    required Color textMuted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(color: textMuted, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
