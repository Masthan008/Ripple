import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _version = '1.0.0');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('About Ripple', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 450),
              childAnimationBuilder: (w) => SlideAnimation(
                verticalOffset: 50, curve: Curves.easeOutBack,
                child: FadeInAnimation(child: w),
              ),
              children: [
                const SizedBox(height: 24),
                // Logo with glow
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.aquaCore.withValues(alpha: 0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: AppColors.glassPanel,
                    radius: 45,
                    child: Icon(Icons.water_drop_rounded,
                        color: AppColors.aquaCore, size: 42),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Ripple',
                    style: AppTextStyles.heading.copyWith(fontSize: 28)),
                const SizedBox(height: 4),
                Text(
                  _version.isNotEmpty
                      ? 'v$_version (Build $_buildNumber)'
                      : 'Loading...',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 8),
                Text(
                  'Liquid Glass × Aquatic AI Chat',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.aquaCore.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),

                // Links
                _linkTile(
                  'Terms of Service',
                  Icons.description_outlined,
                  () => _openUrl('https://ripple.app/terms'),
                ),
                const SizedBox(height: 10),
                _linkTile(
                  'Privacy Policy',
                  Icons.privacy_tip_outlined,
                  () => _openUrl('https://ripple.app/privacy'),
                ),
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
                        applicationLegalese: '© 2024 Ripple',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Text(
                  'Made with 💙 by Ripple Team',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _linkTile(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        borderRadius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(fontSize: 14))),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
}
