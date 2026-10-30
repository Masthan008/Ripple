import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/verified_badge.dart';

import '../../auth/providers/auth_provider.dart';
import 'edit_profile_screen.dart';
import '../../premium/services/subscription_service.dart';
import '../widgets/account_switcher_sheet.dart';
import '../../chat/screens/saved_messages_screen.dart';
import '../../social/services/social_service.dart';

/// Profile Screen — Complete modern overview with enriched account info,
/// subscription status, storage metrics, quick shortcuts, and liquid glass styling.
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
      duration: const Duration(milliseconds: 500),
    )..forward();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final uid = ref.read(currentUserProvider).value?.uid;
    if (uid != null) {
      await ref
          .read(subscriptionServiceProvider)
          .checkSubscriptionTimeline(uid);
      if (mounted) {
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = ref.watch(rippleThemeProvider);
    final isDark = theme.isDark;

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? AppColors.textSecondary : const Color(0xFF64748B);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return SafeArea(
      child: userAsync.when(
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
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.aquaCore,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Set Up Profile',
                        style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            );
          }

          final username = '@${u.name.toLowerCase().replaceAll(' ', '_')}';
          final hasBio = u.bio.trim().isNotEmpty;
          final isVerified = u.isVerified;
          final planName = u.subscriptionPlan ?? 'free';

          return FadeTransition(
            opacity: _animController,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // 1. Top bar: Account Switcher, Settings
                  Row(
                    children: [
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.switch_account_rounded,
                          color: AppColors.aquaCore,
                          size: 24,
                        ),
                        tooltip: 'Switch Account',
                        onPressed: () => AccountSwitcherSheet.show(context),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.settings_outlined,
                          color: textColor,
                          size: 24,
                        ),
                        onPressed: () => context.push('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 2. Large Centered Avatar with Glow
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.aquaCyan.withValues(alpha: 0.25),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: AquaAvatar(
                          imageUrl: u.photoUrl,
                          name: u.name,
                          size: 104,
                        ),
                      ),
                      GlassIconButton(
                        icon: Icon(Icons.edit_rounded, color: isDark ? Colors.white : Colors.black, size: 16),
                        size: 34,
                        quality: GlassQuality.standard,
                        settings: isDark ? LiquidGlassSettings.ios27Dark : LiquidGlassSettings.ios27Light,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. User Name + Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          u.name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      VerifiedBadge(
                        isVerified: isVerified,
                        userId: u.uid,
                        plan: u.subscriptionPlan,
                        size: 20,
                        padding: const EdgeInsets.only(left: 6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Username handle & Online status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          color: AppColors.aquaCore,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: u.isOnline
                              ? AppColors.onlineGreen
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        u.isOnline
                            ? L10n.s(ref, 'online')
                            : L10n.s(ref, 'offline'),
                        style: TextStyle(
                          color: u.isOnline
                              ? AppColors.onlineGreen
                              : textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 4. Quick Actions: Edit Profile & Saved Messages
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPillAction(
                        icon: Icons.edit_note_rounded,
                        label: L10n.s(ref, 'editProfile'),
                        textColor: textColor,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfileScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildPillAction(
                        icon: Icons.bookmark_rounded,
                        label: L10n.s(ref, 'savedMessages'),
                        textColor: textColor,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SavedMessagesScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 5. Subscription Status Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isVerified
                            ? [
                                const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                                const Color(0xFF22D3EE).withValues(alpha: 0.08),
                              ]
                            : [
                                const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                const Color(0xFFF59E0B).withValues(alpha: 0.04),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isVerified
                            ? const Color(0xFF0EA5E9).withValues(alpha: 0.35)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isVerified
                                ? const Color(0xFF0EA5E9).withValues(alpha: 0.2)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            isVerified
                                ? Icons.verified_rounded
                                : Icons.star_rounded,
                            color: isVerified
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVerified
                                    ? '${planName.toUpperCase()} VERIFIED'
                                    : 'Unlock Ripple Premium',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isVerified
                                    ? 'Active Verified status with high-speed cloud'
                                    : 'Get verified badge, up to 10 GB cloud & web sync',
                                style: TextStyle(
                                  color: textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => context.push('/plans'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVerified
                                ? const Color(0xFF0EA5E9)
                                : const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            isVerified ? 'Manage' : 'Upgrade',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. User Bio & Account Details Card
                  _SectionHeader(title: L10n.s(ref, 'account'), color: textColor),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildDetailTile(
                          icon: Icons.format_quote_rounded,
                          title: hasBio ? u.bio : 'No bio set yet',
                          subtitle: 'Status Quote / Bio',
                          textColor: textColor,
                          textMuted: textMuted,
                        ),
                        Divider(height: 1, thickness: 0.5, color: borderColor, indent: 54),
                        _buildDetailTile(
                          icon: Icons.alternate_email_rounded,
                          title: u.email.isNotEmpty ? u.email : 'Not linked',
                          subtitle: 'Account Email',
                          textColor: textColor,
                          textMuted: textMuted,
                        ),
                        Divider(height: 1, thickness: 0.5, color: borderColor, indent: 54),
                        _buildDetailTile(
                          icon: Icons.people_outline_rounded,
                          title: '${u.friends.length} Friends connected',
                          subtitle: 'Ripple Network',
                          textColor: textColor,
                          textMuted: textMuted,
                        ),
                        Divider(height: 1, thickness: 0.5, color: borderColor, indent: 54),
                        _buildDetailTile(
                          icon: Icons.emoji_events_outlined,
                          title: '${SocialService.getRippleRank(u.rippleScore)} (${u.rippleScore} pts)',
                          subtitle: 'Ripple Score & Global Rank',
                          textColor: textColor,
                          textMuted: textMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 7. Media & Storage Overview Card
                  _SectionHeader(title: L10n.s(ref, 'storageAndData'), color: textColor),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cloud_queue_rounded,
                                    color: Color(0xFF0EA5E9), size: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isVerified ? 'Cloud Storage: 4 GB / 10 GB' : 'Cloud Storage: 500 MB Free',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Shared media, voice notes & document backups',
                                      style: TextStyle(color: textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push('/storage-usage'),
                                child: const Text(
                                  'Manage',
                                  style: TextStyle(
                                    color: AppColors.aquaCore,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),



                  // 10. App version footer
                  Text(
                    'Ripple v1.0.0 • E2EE Encrypted',
                    style: TextStyle(
                      color: textMuted.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 36),
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
    required Color textColor,
    required Color cardBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
    required Color textColor,
    required Color textMuted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.aquaCore.withValues(alpha: 0.12),
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
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textMuted,
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
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: color.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
