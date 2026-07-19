import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../../auth/providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import 'qr_code_screen.dart';
import 'account_security_screen.dart';
import 'linked_devices_screen.dart';
import 'notifications_settings_screen.dart';
import 'appearance_screen.dart';
import 'accessibility_screen.dart';
import 'language_screen.dart';
import 'chat_backup_screen.dart';
import 'app_icon_screen.dart';
import '../../premium/services/subscription_service.dart';
import '../providers/settings_provider.dart';
import 'storage_usage_screen.dart';
import 'data_usage_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'contact_support_screen.dart';
import 'system_status_screen.dart';
import '../../chat/screens/saved_messages_screen.dart';
import '../../social/services/social_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _subStatus = 'none';

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid != null) {
      final status = await ref.read(subscriptionServiceProvider).checkSubscriptionTimeline(uid);
      if (mounted) {
        setState(() {
          _subStatus = status;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = ref.watch(rippleThemeProvider);

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: user.when(
          loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.aquaCore))),
          error: (e, _) => Center(child: Text('Error: $e', style: AppTextStyles.caption)),
          data: (u) {
            if (u == null) return const SizedBox.shrink();
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Profile Card Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
                    ),
                    child: Row(
                      children: [
                        AquaAvatar(
                          imageUrl: u.photoUrl,
                          name: u.name,
                          size: 60,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      u.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  VerifiedBadge(
                                    isVerified: u.isVerified,
                                    userId: u.uid,
                                    plan: u.subscriptionPlan,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                u.email,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.onlineGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('online', style: TextStyle(color: AppColors.onlineGreen, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: AppColors.aquaCore),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Premium Section if not verified
                  if (!u.isVerified) ...[
                    GestureDetector(
                      onTap: () => context.push('/plans'),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0x330EA5E9), Color(0x1122D3EE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.aquaCore.withOpacity(0.3), width: 0.5),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: AppColors.aquaCore, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ripple Premium',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Get a verified blue badge & premium layouts',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.white30),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Settings Groups
                  _buildGroupHeader('Account'),
                  _buildGroupCard([
                    _SettingsRow(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFFFF9800),
                      title: L10n.s(ref, 'accountSecurity'),
                      subtitle: 'Two-step lock & advanced protocols',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSecurityScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.devices_other_rounded,
                      iconColor: AppColors.aquaCore,
                      title: 'Linked Devices',
                      subtitle: 'Active companions and paired machines',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkedDevicesScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.bookmark_rounded,
                      iconColor: Colors.amber,
                      title: L10n.s(ref, 'savedMessages'),
                      subtitle: 'Quantum storage notebook',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesScreen())),
                    ),
                  ]),

                  _buildGroupHeader('Preferences'),
                  _buildGroupCard([
                    _SettingsRow(
                      icon: Icons.notifications_outlined,
                      iconColor: const Color(0xFF2196F3),
                      title: L10n.s(ref, 'notifications'),
                      subtitle: 'Alerts, vibrations & custom sounds',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.lock_outline_rounded,
                      iconColor: const Color(0xFF4CAF50),
                      title: L10n.s(ref, 'privacyAndSecurity'),
                      subtitle: 'Status visible, decoy modes & blocklist',
                      onTap: () => context.push('/privacy-settings'),
                    ),
                    _SettingsRow(
                      icon: Icons.color_lens_outlined,
                      iconColor: const Color(0xFFE91E63),
                      title: L10n.s(ref, 'appearance'),
                      subtitle: 'Color schemes & interactive glass effects',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.accessibility_new_outlined,
                      iconColor: const Color(0xFF673AB7),
                      title: 'Accessibility',
                      subtitle: 'Contrast, text size & speech feedback',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibilityScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.cloud_upload_rounded,
                      iconColor: AppColors.aquaCore,
                      title: 'Chat Backup & Restore',
                      subtitle: 'Google Drive snapshot manager',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatBackupScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF009688),
                      title: L10n.s(ref, 'language'),
                      subtitle: ref.watch(languageProvider),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.app_settings_alt_rounded,
                      iconColor: const Color(0xFFFF9800),
                      title: 'App Icon',
                      subtitle: 'Interactive launcher selector',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppIconScreen())),
                    ),
                  ]),

                  _buildGroupHeader('Storage & Data'),
                  _buildGroupCard([
                    _SettingsRow(
                      icon: Icons.storage_rounded,
                      iconColor: const Color(0xFF795548),
                      title: L10n.s(ref, 'storageUsage'),
                      subtitle: 'Cache cleaner and folder metrics',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageUsageScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.cloud_download_outlined,
                      iconColor: const Color(0xFF607D8B),
                      title: L10n.s(ref, 'dataUsage'),
                      subtitle: 'Network counters and media download',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataUsageScreen())),
                    ),
                  ]),

                  _buildGroupHeader('Support & About'),
                  _buildGroupCard([
                    _SettingsRow(
                      icon: Icons.help_outline_rounded,
                      iconColor: const Color(0xFF3F51B5),
                      title: L10n.s(ref, 'helpFaq'),
                      subtitle: 'Instant self-service guidelines',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.contact_support_outlined,
                      iconColor: const Color(0xFF00E676),
                      title: 'Contact Support',
                      subtitle: 'Send feedback or bug report ticket',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.analytics_outlined,
                      iconColor: const Color(0xFFE040FB),
                      title: 'System Diagnostics',
                      subtitle: 'Ping latency and operational status',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemStatusScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: AppColors.aquaCyan,
                      title: L10n.s(ref, 'aboutRipple'),
                      subtitle: 'Ripple legal, terms and version info',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Sign Out Button
                  GestureDetector(
                    onTap: () => _handleSignOut(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.errorRed.withOpacity(0.2), width: 0.5),
                      ),
                      child: Center(
                        child: Text(
                          L10n.s(ref, 'signOut'),
                          style: const TextStyle(
                            color: AppColors.errorRed,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 6, top: 16),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          if (index == children.length - 1) return children[index];
          return Column(
            children: [
              children[index],
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: Colors.white.withOpacity(0.04),
                indent: 52,
              ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(L10n.s(ref, 'signOutTitle'), style: const TextStyle(color: Colors.white)),
        content: Text(L10n.s(ref, 'confirmSignOut'), style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.s(ref, 'cancel'), style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.s(ref, 'signOut'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        context.go('/splash');
      }
    }
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
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
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}
