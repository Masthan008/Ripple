import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Padding(
      padding: padding,
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
