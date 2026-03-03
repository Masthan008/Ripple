import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../auth/models/user_model.dart';
import '../providers/friends_provider.dart';

/// Friend Requests Screen — PRD §6.7
/// Accept / Reject incoming friend requests
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(friendRequestsReceivedProvider);

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text(AppStrings.friendRequests, style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
      ),
      body: requests.when(
        loading: () => ShimmerLoader.list(count: 4),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.caption),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_disabled_rounded,
                      color: AppColors.aquaCore.withValues(alpha: 0.3),
                      size: 64),
                  const SizedBox(height: 12),
                  Text('No pending requests',
                      style: AppTextStyles.bodySmall),
                  const SizedBox(height: 4),
                  Text('Friend requests will appear here',
                      style: AppTextStyles.caption),
                ],
              ),
            );
          }

          return AnimationLimiter(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: users.length,
              itemBuilder: (ctx, i) {
                return AnimationConfiguration.staggeredList(
                  position: i,
                  duration: const Duration(milliseconds: 450),
                  child: SlideAnimation(
                    verticalOffset: 50,
                    curve: Curves.easeOutBack,
                    child: FadeInAnimation(
                      child: _RequestCard(user: users[i]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Individual friend request card with Accept / Decline buttons
class _RequestCard extends ConsumerStatefulWidget {
  final UserModel user;

  const _RequestCard({required this.user});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _isLoading = false;

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(friendsServiceProvider);
      await service.acceptFriendRequest(widget.user.uid);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(friendsServiceProvider);
      await service.rejectFriendRequest(widget.user.uid);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AquaAvatar(
              imageUrl: widget.user.photoUrl,
              name: widget.user.name,
              size: 48,
              showOnlineDot: true,
              isOnline: widget.user.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.user.name,
                    style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.user.email,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Action buttons
                  if (_isLoading)
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(AppColors.aquaCore),
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Accept button (green glass)
                        Expanded(
                          child: WaterRippleEffect(
                            onTap: _accept,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.onlineGreen
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.onlineGreen
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  AppStrings.accept,
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.onlineGreen,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Decline button (red glass)
                        Expanded(
                          child: WaterRippleEffect(
                            onTap: _decline,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.errorRed
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.errorRed
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  AppStrings.decline,
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.errorRed,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
