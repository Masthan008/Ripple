import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import 'software_update_screen.dart';

/// Redesigned, Theme-Aware Liquid Glass About Ripple Screen
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> with SingleTickerProviderStateMixin {
  String _version = '1.0.1';
  String _buildNumber = '43';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version.isNotEmpty ? info.version : '1.0.1';
          _buildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : '43';
        });
      }
    } catch (_) {}
  }

  void _checkForUpdates() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SoftwareUpdateScreen()),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open external link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.85);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: Text(
          'About Ripple',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 40,
                curve: Curves.easeOutCubic,
                child: FadeInAnimation(child: w),
              ),
              children: [
                const SizedBox(height: 8),

                // Official Animated Cyber Logo Squircle
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCore.withValues(alpha: 0.25 + (_pulseController.value * 0.15)),
                              blurRadius: 28 + (_pulseController.value * 12),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.asset(
                            'assets/images/ripple_logo.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                Text(
                  'RIPPLE',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.aquaCore.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'v$_version • Build $_buildNumber',
                    style: const TextStyle(
                      color: AppColors.aquaCore,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Zero-Trace Encrypted Messenger × Sovereign Privacy',
                  style: TextStyle(color: textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Check for Updates Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _checkForUpdates,
                    icon: const Icon(Icons.system_update_rounded, color: AppColors.aquaCore, size: 20),
                    label: const Text(
                      'Check for System Updates',
                      style: TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.aquaCore, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Protocol & Security Architecture Card
                _sectionHeader('SECURITY & PROTOCOLS', AppColors.aquaCore),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 0.8),
                  ),
                  child: Column(
                    children: [
                      _buildSpecTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Double Ratchet & Signal Protocol',
                        subtitle: 'End-to-end forward secret cryptographic sessions',
                        textColor: textColor,
                        textMuted: textMuted,
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildSpecTile(
                        icon: Icons.hub_rounded,
                        iconColor: const Color(0xFF0EA5E9),
                        title: 'Decentralized Offline Mesh',
                        subtitle: 'Nearby Bluetooth LE & Wi-Fi Direct peer fallback',
                        textColor: textColor,
                        textMuted: textMuted,
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildSpecTile(
                        icon: Icons.visibility_off_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        title: 'Zero Metadata Retention',
                        subtitle: 'Ephemeral message routing with no telemetry logging',
                        textColor: textColor,
                        textMuted: textMuted,
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildSpecTile(
                        icon: Icons.sync_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Dual-Engine Over-the-Air Updates',
                        subtitle: 'Instant Shorebird code push & Catalyst GitHub release installer',
                        textColor: textColor,
                        textMuted: textMuted,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Open Source & Community Links
                _sectionHeader('COMMUNITY & REPOSITORY', const Color(0xFF3B82F6)),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 0.8),
                  ),
                  child: Column(
                    children: [
                      _buildLinkTile(
                        icon: Icons.code_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'GitHub Source Repository',
                        subtitle: 'github.com/Masthan008/Ripple',
                        textColor: textColor,
                        textMuted: textMuted,
                        onTap: () => _launchUrl('https://github.com/Masthan008/Ripple'),
                      ),
                      Divider(color: cardBorder, height: 1, indent: 56),
                      _buildLinkTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: const Color(0xFF10B981),
                        title: 'Privacy Policy & Terms',
                        subtitle: 'Zero data retention principles',
                        textColor: textColor,
                        textMuted: textMuted,
                        onTap: () => _launchUrl('https://github.com/Masthan008/Ripple#privacy'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Footer
                Text(
                  'Crafted with Sovereign Privacy in mind\nRipple © 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 11, height: 1.5),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSpecTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color textMuted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, color: textMuted, size: 16),
          ],
        ),
      ),
    );
  }
}
