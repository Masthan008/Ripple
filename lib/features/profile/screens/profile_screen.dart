import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../../auth/providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'qr_code_screen.dart';
import 'account_security_screen.dart';
import 'notifications_settings_screen.dart';
import 'privacy_screen.dart';
import 'appearance_screen.dart';
import 'language_screen.dart';
import 'storage_usage_screen.dart';
import 'data_usage_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import '../../chat/screens/saved_messages_screen.dart';

/// Profile Screen — PRD §6.8
/// Full profile view with avatar, name, email, settings, about, and sign out
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return SafeArea(
      child: user.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.caption),
        ),
        data: (u) {
          if (u == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline_rounded,
                      color: AppColors.aquaCore.withValues(alpha: 0.3),
                      size: 80),
                  const SizedBox(height: 16),
                  Text('Complete your profile',
                      style: AppTextStyles.heading.copyWith(fontSize: 20)),
                  const SizedBox(height: 8),
                  Text('Set up your name and photo to get started',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text('Set Up Profile',
                            style: AppTextStyles.button),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return FadeTransition(
            opacity: _animController,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Header
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Profile', style: AppTextStyles.heading),
                  ),

                  const SizedBox(height: 16),

                  // ─── Avatar with glow ─────────────────────
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCyan.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: AquaAvatar(
                          imageUrl: u.photoUrl,
                          name: u.name,
                          size: 100,
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.abyssBackground,
                            width: 3,
                          ),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Name & Email ──────────────────────────
                  Text(
                    u.name,
                    style: AppTextStyles.display.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 4),
                  Text(u.email, style: AppTextStyles.caption),

                  const SizedBox(height: 8),

                  // Online status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.aquaCore.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: u.isOnline
                                ? AppColors.onlineGreen
                                : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          u.isOnline ? 'Online' : 'Offline',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: u.isOnline
                                ? AppColors.onlineGreen
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Account Section ──────────────────────
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Change name, bio, photo',
                    iconColor: AppColors.aquaCore,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const EditProfileScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.qr_code_rounded,
                    title: 'QR Code',
                    subtitle: 'Share your profile',
                    iconColor: const Color(0xFF9C27B0),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const QrCodeScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Account Security',
                    subtitle: 'Password, 2FA',
                    iconColor: const Color(0xFFFF9800),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AccountSecurityScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.bookmark_rounded,
                    title: 'Saved Messages',
                    subtitle: 'View your starred messages',
                    iconColor: Colors.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SavedMessagesScreen())),
                  ),

                  const SizedBox(height: 20),

                  // ─── Preferences Section ──────────────────
                  _SectionHeader(title: 'Preferences'),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Push notifications, sounds',
                    iconColor: const Color(0xFF2196F3),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const NotificationsSettingsScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy',
                    subtitle: 'Blocked users, read receipts',
                    iconColor: const Color(0xFF4CAF50),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const PrivacyScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.color_lens_outlined,
                    title: 'Appearance',
                    subtitle: 'Theme, chat bubbles, font size',
                    iconColor: const Color(0xFFE91E63),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AppearanceScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    subtitle: 'English',
                    iconColor: const Color(0xFF009688),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const LanguageScreen())),
                  ),

                  const SizedBox(height: 20),

                  // ─── Storage Section ──────────────────────
                  _SectionHeader(title: 'Storage & Data'),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.storage_rounded,
                    title: 'Storage Usage',
                    subtitle: 'Manage cache, media',
                    iconColor: const Color(0xFF795548),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const StorageUsageScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.cloud_download_outlined,
                    title: 'Data Usage',
                    subtitle: 'Auto-download, quality',
                    iconColor: const Color(0xFF607D8B),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const DataUsageScreen())),
                  ),

                  const SizedBox(height: 20),

                  // ─── Support Section ──────────────────────
                  _SectionHeader(title: 'Support'),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Help & FAQ',
                    subtitle: 'Get help, report issues',
                    iconColor: const Color(0xFF3F51B5),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const HelpScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Ripple',
                    subtitle: 'Version, licenses, terms',
                    iconColor: AppColors.aquaCyan,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const AboutScreen())),
                  ),
                  _SettingsTile(
                    icon: Icons.star_outline_rounded,
                    title: 'Rate Us',
                    subtitle: 'Love Ripple? Rate us!',
                    iconColor: const Color(0xFFFFC107),
                    onTap: () async {
                      final url = Platform.isAndroid
                          ? 'market://details?id=com.yourcompany.ripple'
                          : 'https://apps.apple.com/app/idYOUR_APP_ID';
                      try {
                        await launchUrl(Uri.parse(url));
                      } catch (_) {
                        if (Platform.isAndroid) {
                          await launchUrl(Uri.parse(
                              'https://play.google.com/store/apps/details?id=com.yourcompany.ripple'));
                        }
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // ─── Sign Out ─────────────────────────────
                  WaterRippleEffect(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF0D1B2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text('Sign Out?',
                              style: AppTextStyles.body
                                  .copyWith(fontWeight: FontWeight.w600)),
                          content: Text(
                            'Are you sure you want to sign out?',
                            style: AppTextStyles.caption,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: AppColors.textMuted)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text('Sign Out',
                                  style:
                                      TextStyle(color: AppColors.errorRed)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        final authService = ref.read(authServiceProvider);
                        await authService.signOut();
                        // GoRouter auto-redirects to /login via auth state listener
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.errorRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout_rounded,
                                color: AppColors.errorRed, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: AppTextStyles.button
                                  .copyWith(color: AppColors.errorRed),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App version
                  Text(
                    'Ripple v1.0.0 • Made with 💙',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.aquaCore.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ─── Settings Tile ──────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          borderRadius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.body.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
