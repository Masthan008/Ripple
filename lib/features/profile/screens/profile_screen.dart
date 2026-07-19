import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart'; // Add this
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../../shared/widgets/glass_card.dart';
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
import '../providers/settings_provider.dart'; // Add this
import 'storage_usage_screen.dart';
import 'data_usage_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'contact_support_screen.dart';
import 'system_status_screen.dart';
import '../../chat/screens/saved_messages_screen.dart';
import '../../social/services/social_service.dart';
import '../../social/widgets/achievements_section.dart';

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
  String _subStatus = 'none';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    // Wait a brief moment for auth state to populate
    await Future.delayed(const Duration(milliseconds: 200));
    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid != null) {
      final status = await ref.read(subscriptionServiceProvider).checkSubscriptionTimeline(uid);
      if (mounted) {
        setState(() {
          _subStatus = status;
        });
        if (status == 'expired') {
          _showExpiryDialog();
        }
      }
    }
  }

  void _showExpiryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Badge Expired',
          style: AppTextStyles.heading.copyWith(color: AppColors.errorRed),
        ),
        content: Text(
          'Your Ripple Verified badge subscription period has ended. Please renew to restore your verified badge.',
          style: AppTextStyles.body.copyWith(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/plans');
            },
            child: const Text('Renew Now', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
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
        loading:
            () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
              ),
            ),
        error:
            (e, _) =>
                Center(child: Text('Error: $e', style: AppTextStyles.caption)),
        data: (u) {
          if (u == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.aquaCore.withValues(alpha: 0.3),
                    size: 80,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Complete your profile',
                    style: AppTextStyles.heading.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up your name and photo to get started',
                    style: AppTextStyles.caption,
                  ),
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
                        onPressed:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Set Up Profile',
                          style: AppTextStyles.button,
                        ),
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
                    child: Text(
                      L10n.s(ref, 'profile'),
                      style: AppTextStyles.heading,
                    ),
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
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─── Name & Email ──────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          u.name,
                          style: AppTextStyles.display.copyWith(fontSize: 26),
                        ),
                      ),
                      VerifiedBadge(
                        isVerified: u.isVerified,
                        userId: u.uid,
                        plan: u.subscriptionPlan,
                        size: 24,
                        padding: const EdgeInsets.only(left: 6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(u.email, style: AppTextStyles.caption),
                      const SizedBox(width: 8),
                      // Ripple Score
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: SocialService.getRippleRankColor(
                            u.rippleScore,
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              SocialService.getRippleRank(u.rippleScore),
                              style: TextStyle(
                                color: SocialService.getRippleRankColor(
                                  u.rippleScore,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              u.rippleScore.toString(),
                              style: TextStyle(
                                color: SocialService.getRippleRankColor(
                                  u.rippleScore,
                                ),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Online status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
                            color:
                                u.isOnline
                                    ? AppColors.onlineGreen
                                    : AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          u.isOnline
                              ? L10n.s(ref, 'online')
                              : L10n.s(ref, 'offline'),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color:
                                u.isOnline
                                    ? AppColors.onlineGreen
                                    : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  AchievementsSection(uid: u.uid),

                  const SizedBox(height: 24),

                  // ─── Social & Activity Section ────────────
                  _SectionHeader(title: L10n.s(ref, 'socialAndActivity')),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.emoji_events_rounded,
                    title: L10n.s(ref, 'leaderboard'),
                    subtitle: L10n.s(ref, 'leaderboardDesc'),
                    iconColor: Colors.amber,
                    onTap: () => context.push('/leaderboard'),
                  ),
                  _SettingsTile(
                    icon: Icons.military_tech_rounded,
                    title: 'Challenges',
                    subtitle: 'Complete weekly challenges & earn badges',
                    iconColor: Colors.green,
                    onTap: () => context.push('/challenges'),
                  ),
                  _SettingsTile(
                    icon: Icons.card_giftcard_rounded,
                    title: 'Gift Cards',
                    subtitle: 'Send themed digital gifts to friends',
                    iconColor: Colors.pink,
                    onTap: () => context.push('/gift-cards'),
                  ),
                  _SettingsTile(
                    icon: Icons.people_alt_rounded,
                    title: L10n.s(ref, 'friendSuggestions'),
                    subtitle: L10n.s(ref, 'friendSuggestionsDesc'),
                    iconColor: AppColors.aquaCore,
                    onTap: () => context.push('/friend-suggestions'),
                  ),
                  _SettingsTile(
                    icon: Icons.local_fire_department_rounded,
                    title: L10n.s(ref, 'activityFeed'),
                    subtitle: L10n.s(ref, 'activityFeedDesc'),
                    iconColor: Colors.orange,
                    onTap: () => context.push('/activity-feed'),
                  ),
                  _SettingsTile(
                    icon: Icons.visibility_rounded,
                    title: L10n.s(ref, 'profileVisitors'),
                    subtitle: L10n.s(ref, 'profileVisitorsDesc'),
                    iconColor: Colors.purple,
                    onTap: () => context.push('/profile-visitors'),
                  ),

                  const SizedBox(height: 20),

                  if (_subStatus == 'expiring_soon') ...[
                    GestureDetector(
                      onTap: () => context.push('/plans'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0x20F59E0B), Color(0x10EF4444)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verified Badge Expiring Soon!',
                                    style: AppTextStyles.headingSmall.copyWith(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your Ripple Verified tick mark will expire in less than 3 days. Tap here to renew your plan.',
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ─── Premium Section ──────────────────────
                  _SectionHeader(title: 'Ripple Premium'),
                  const SizedBox(height: 8),
                  _SettingsTile(
                    icon: Icons.verified_rounded,
                    title: 'Ripple Verified Badge',
                    subtitle: u.isVerified 
                        ? 'Your profile is verified and active' 
                        : u.verificationStatus == 'pending'
                            ? 'Verification status: Pending review'
                            : 'Get a verified blue badge & premium plans',
                    iconColor: AppColors.aquaCore,
                    onTap: () {
                      if (u.verificationStatus == 'pending') {
                        context.push('/verification-waiting');
                      } else {
                        context.push('/plans');
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // ─── Account Section ──────────────────────
                  _SectionHeader(title: L10n.s(ref, 'account')),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: L10n.s(ref, 'editProfile'),
                    subtitle: L10n.s(ref, 'editProfileDesc'),
                    iconColor: AppColors.aquaCore,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.qr_code_rounded,
                    title: L10n.s(ref, 'qrCode'),
                    subtitle: L10n.s(ref, 'qrCodeDesc'),
                    iconColor: const Color(0xFF9C27B0),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QrCodeScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: L10n.s(ref, 'accountSecurity'),
                    subtitle: L10n.s(ref, 'accountSecurityDesc'),
                    iconColor: const Color(0xFFFF9800),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountSecurityScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.devices_other_rounded,
                    title: 'Linked Devices',
                    subtitle: 'Manage active companion sessions and pair devices',
                    iconColor: AppColors.aquaCore,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LinkedDevicesScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.bookmark_rounded,
                    title: L10n.s(ref, 'savedMessages'),
                    subtitle: L10n.s(ref, 'savedMessagesDesc'),
                    iconColor: Colors.amber,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedMessagesScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.psychology_rounded,
                    title: L10n.s(ref, 'aiFeatures'),
                    subtitle: L10n.s(ref, 'aiFeaturesDesc'),
                    iconColor: AppColors.aquaCore,
                    onTap: () => context.push('/ai-settings'),
                  ),

                  const SizedBox(height: 20),

                  // ─── Preferences Section ──────────────────
                  _SectionHeader(title: L10n.s(ref, 'preferences')),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: L10n.s(ref, 'notifications'),
                    subtitle: L10n.s(ref, 'notificationsDesc'),
                    iconColor: const Color(0xFF2196F3),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsSettingsScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: L10n.s(ref, 'privacyAndSecurity'),
                    subtitle: L10n.s(ref, 'privacyAndSecurityDesc'),
                    iconColor: const Color(0xFF4CAF50),
                    onTap: () => context.push('/privacy-settings'),
                  ),
                  _SettingsTile(
                    icon: Icons.color_lens_outlined,
                    title: L10n.s(ref, 'appearance'),
                    subtitle: L10n.s(ref, 'appearanceDesc'),
                    iconColor: const Color(0xFFE91E63),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AppearanceScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.accessibility_new_outlined,
                    title: 'Accessibility',
                    subtitle: 'High contrast, larger text, reduced motion',
                    iconColor: const Color(0xFF673AB7),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccessibilityScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.cloud_upload_rounded,
                    title: 'Chat Backup & Restore',
                    subtitle: 'Back up and restore your chats to Cloud Drive',
                    iconColor: AppColors.aquaCore,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatBackupScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    title: L10n.s(ref, 'language'),
                    subtitle: ref.watch(languageProvider),
                    iconColor: const Color(0xFF009688),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LanguageScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.app_settings_alt_rounded,
                    title: 'App Icon',
                    subtitle: 'Change app launcher icon',
                    iconColor: const Color(0xFFFF9800),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AppIconScreen(),
                          ),
                        ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Storage Section ──────────────────────
                  _SectionHeader(title: L10n.s(ref, 'storageAndData')),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.storage_rounded,
                    title: L10n.s(ref, 'storageUsage'),
                    subtitle: L10n.s(ref, 'storageUsageDesc'),
                    iconColor: const Color(0xFF795548),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StorageUsageScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.cloud_download_outlined,
                    title: L10n.s(ref, 'dataUsage'),
                    subtitle: L10n.s(ref, 'dataUsageDesc'),
                    iconColor: const Color(0xFF607D8B),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DataUsageScreen(),
                          ),
                        ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Support Section ──────────────────────
                  _SectionHeader(title: L10n.s(ref, 'support')),
                  const SizedBox(height: 8),

                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    title: L10n.s(ref, 'helpFaq'),
                    subtitle: L10n.s(ref, 'helpFaqDesc'),
                    iconColor: const Color(0xFF3F51B5),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpScreen()),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.contact_support_outlined,
                    title: 'Contact Support',
                    subtitle: 'Submit a feedback or bug report ticket',
                    iconColor: const Color(0xFF00E676),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactSupportScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.analytics_outlined,
                    title: 'System Diagnostics',
                    subtitle: 'Check Firebase server latency & status',
                    iconColor: const Color(0xFFE040FB),
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SystemStatusScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: L10n.s(ref, 'aboutRipple'),
                    subtitle: L10n.s(ref, 'aboutRippleDesc'),
                    iconColor: AppColors.aquaCyan,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                  ),
                  _SettingsTile(
                    icon: Icons.star_outline_rounded,
                    title: L10n.s(ref, 'rateUs'),
                    subtitle: L10n.s(ref, 'rateUsDesc'),
                    iconColor: const Color(0xFFFFC107),
                    onTap: () async {
                      final url =
                          Platform.isAndroid
                              ? 'market://details?id=com.yourcompany.ripple'
                              : 'https://apps.apple.com/app/idYOUR_APP_ID';
                      try {
                        await launchUrl(Uri.parse(url));
                      } catch (_) {
                        if (Platform.isAndroid) {
                          await launchUrl(
                            Uri.parse(
                              'https://play.google.com/store/apps/details?id=com.yourcompany.ripple',
                            ),
                          );
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
                        builder:
                            (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF0D1B2A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                L10n.s(ref, 'signOutTitle'),
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              content: Text(
                                L10n.s(ref, 'confirmSignOut'),
                                style: AppTextStyles.caption,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    L10n.s(ref, 'cancel'),
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    L10n.s(ref, 'signOut'),
                                    style: TextStyle(color: AppColors.errorRed),
                                  ),
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
                            Icon(
                              Icons.logout_rounded,
                              color: AppColors.errorRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              L10n.s(ref, 'signOut'),
                              style: AppTextStyles.button.copyWith(
                                color: AppColors.errorRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // App version
                  Text(
                    'Ripple v1.0.0',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
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
                    Text(
                      title,
                      style: AppTextStyles.body.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
