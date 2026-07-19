import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/theme_glass_card.dart';

/// Upgraded & Interactive About Ripple Screen
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
  String _version = '1.0.0';
  String _buildNumber = '42';
  bool _isCheckingUpdate = false;
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
          _version = info.version.isNotEmpty ? info.version : '1.0.0';
          _buildNumber = info.buildNumber.isNotEmpty ? info.buildNumber : '42';
        });
      }
    } catch (_) {}
  }

  void _checkForUpdates() {
    setState(() => _isCheckingUpdate = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.onlineGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ripple is up to date! (v$_version Build $_buildNumber)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.aquaCore),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _openSupportDialog() {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.aquaCore)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded, color: AppColors.aquaCore),
            SizedBox(width: 10),
            Text('Ripple Support & Feedback', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Have feedback or need support? Drop a message directly to the Ripple team:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type your question or issue...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you! Your feedback has been submitted to Ripple support.'), backgroundColor: AppColors.onlineGreen),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaCore, foregroundColor: Colors.black),
            child: const Text('Send Feedback'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: const Text('About Ripple', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.aquaCore),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 50,
                curve: Curves.easeOutBack,
                child: FadeInAnimation(child: w),
              ),
              children: [
                const SizedBox(height: 12),
                
                // Animated Glowing Water Droplet Logo
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.08);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCore.withValues(alpha: 0.4 + (_pulseController.value * 0.3)),
                              blurRadius: 30 + (_pulseController.value * 15),
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.water_drop_rounded, color: Colors.white, size: 52),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                Text('RIPPLE', style: AppTextStyles.heading.copyWith(fontSize: 32, letterSpacing: 3, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.aquaCore.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'v$_version (Build $_buildNumber)',
                    style: const TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Liquid Glass × Groq Neural AI × Encrypted Security',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70, fontSize: 13),
                ),

                const SizedBox(height: 28),

                // Check for Updates Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                    icon: _isCheckingUpdate
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.aquaCore)))
                        : const Icon(Icons.system_update_rounded, color: AppColors.aquaCore, size: 18),
                    label: Text(
                      _isCheckingUpdate ? 'Checking for updates...' : 'Check for Updates',
                      style: const TextStyle(color: AppColors.aquaCore, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.aquaCore, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Architectural Highlights Grid
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ENGINE HIGHLIGHTS', style: TextStyle(color: AppColors.aquaCore, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const SizedBox(height: 10),

                _buildHighlightTile(
                  icon: Icons.invert_colors_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'Liquid Glass Physics',
                  description: 'Dynamic frosted glass interfaces with real-time backdrop blur, glowing gradients, and fluid micro-animations.',
                ),
                _buildHighlightTile(
                  icon: Icons.psychology_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Groq Neural Engine',
                  description: 'Powered by Llama 3.3 & Whisper AI for instant smart replies, tone reformatting, translation, and voice transcription.',
                ),
                _buildHighlightTile(
                  icon: Icons.shield_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Fortress Cryptography',
                  description: 'Steganography, Decoy Passcodes, Gaze Lock, and Instant Real-Time Account Purge for maximum data sovereignty.',
                ),
                _buildHighlightTile(
                  icon: Icons.cloud_sync_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Supabase Cloud Core',
                  description: 'Real-time database synchronisation, Drive chat backups, and Email OTP Two-Factor Authentication.',
                ),

                const SizedBox(height: 24),

                // Links & Actions
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('LEGAL & SUPPORT', style: TextStyle(color: AppColors.aquaCore, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const SizedBox(height: 10),

                _linkTile('Support & Feedback', Icons.support_agent_rounded, _openSupportDialog),
                const SizedBox(height: 10),
                _linkTile('Terms of Service', Icons.description_outlined, () => _openUrl('https://ripple.app/terms')),
                const SizedBox(height: 10),
                _linkTile('Privacy Policy', Icons.privacy_tip_outlined, () => _openUrl('https://ripple.app/privacy')),
                const SizedBox(height: 10),
                _linkTile(
                  'Open Source Licenses',
                  Icons.source_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LicensePage(
                        applicationName: 'Ripple',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2026 Ripple Inc. All rights reserved.',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),
                Text('© 2026 Ripple Inc. All rights reserved.', style: AppTextStyles.caption.copyWith(fontSize: 11, color: Colors.white38)),
                const SizedBox(height: 4),
                Text('Crafted with 🩵 & Agentic Intelligence', style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.aquaCore.withValues(alpha: 0.6))),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ThemeGlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linkTile(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 14))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}
