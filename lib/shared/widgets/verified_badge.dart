import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../features/chat/providers/chat_provider.dart';

/// Reusable verified badge next to user names that adapts to subscription plans.
class VerifiedBadge extends ConsumerWidget {
  final bool isVerified;
  final String? userId;
  final String? plan;
  final double size;
  final EdgeInsetsGeometry padding;

  const VerifiedBadge({
    super.key,
    required this.isVerified,
    this.userId,
    this.plan,
    this.size = 16,
    this.padding = const EdgeInsets.only(left: 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVerified) return const SizedBox.shrink();

    String currentPlan = plan ?? '';

    // If userId is provided, watch their subscriptionPlan dynamically
    if (userId != null && plan == null) {
      final userAsync = ref.watch(chatPartnerProvider(userId!));
      currentPlan = userAsync.value?.subscriptionPlan ?? '';
    }

    String assetPath = 'assets/images/icons8-verified-badge-96.gif';
    if (currentPlan == 'Gold Monthly') {
      assetPath = 'assets/images/gold_verified_badge.png';
    } else if (currentPlan == 'Abyss Platinum') {
      assetPath = 'assets/images/abyss_verified_badge.png';
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: AppColors.aquaCore),
                SizedBox(width: 8),
                Text('Ripple Verification Tiers', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Verified badges distinguish premium subscription tiers and standard trial verifications on Ripple:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                _buildBadgeRow(
                  'assets/images/icons8-verified-badge-96.gif',
                  'Premium Trial / Free',
                  'Standard green-glass identity verification mark.',
                ),
                const SizedBox(height: 14),
                _buildBadgeRow(
                  'assets/images/gold_verified_badge.png',
                  'Gold Monthly',
                  'Exclusive gold tier verified checkmark badge.',
                ),
                const SizedBox(height: 14),
                _buildBadgeRow(
                  'assets/images/abyss_verified_badge.png',
                  'Abyss Platinum',
                  'Elite cyan glass-glowing badge for VIP tier.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppColors.aquaCore)),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: padding,
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildBadgeRow(String assetPath, String planName, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(assetPath, width: 24, height: 24, fit: BoxFit.contain),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                planName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
