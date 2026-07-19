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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Telegram-style Top bar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 24),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrCodeScreen()),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Large centered avatar with cyan glow
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCyan.withOpacity(0.25),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: AquaAvatar(
                          imageUrl: u.photoUrl,
                          name: u.name,
                          size: 110,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        ),
                        child: Container(
                          width: 32,
                          height: 32,
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // User name + verified badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          u.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      VerifiedBadge(
                        isVerified: u.isVerified,
                        userId: u.uid,
                        plan: u.subscriptionPlan,
                        size: 20,
                        padding: const EdgeInsets.only(left: 6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Status text (Online)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: u.isOnline ? AppColors.onlineGreen : Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        u.isOnline ? L10n.s(ref, 'online') : L10n.s(ref, 'offline'),
                        style: TextStyle(
                          color: u.isOnline ? AppColors.onlineGreen : Colors.white30,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons Row: Edit Info, Settings, Saved Messages
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPillAction(
                        icon: Icons.edit_note_rounded,
                        label: 'Edit Info',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                        ),
                      ),
                      _buildPillAction(
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                      _buildPillAction(
                        icon: Icons.bookmark_rounded,
                        label: 'Saved',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedMessagesScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Details Cards Group
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Details'.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _buildDetailTile(
                          icon: Icons.alternate_email_rounded,
                          title: u.email,
                          subtitle: 'Email / Username',
                        ),
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: Colors.white.withOpacity(0.04),
                          indent: 52,
                        ),
                        _buildDetailTile(
                          icon: Icons.emoji_events_outlined,
                          title: '${SocialService.getRippleRank(u.rippleScore)} (${u.rippleScore} pts)',
                          subtitle: 'Ripple Rank & Score',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Achievements Section
                  AchievementsSection(uid: u.uid),
                  const SizedBox(height: 24),

                  // App version
                  Text(
                    'Ripple v1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 11,
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

  Widget _buildPillAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.aquaCore.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.aquaCore, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
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
