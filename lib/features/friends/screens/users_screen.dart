import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../auth/models/user_model.dart';
import '../providers/friends_provider.dart';

/// Users Discovery Screen — PRD §3.2
/// Search / discover all users (excluding self and blocked)
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = ref.watch(allUsersProvider);
    final sentRequests = ref.watch(friendRequestsSentProvider);
    final blockedUsers = ref.watch(blockedUsersProvider);
    final friendsList = ref.watch(friendsListProvider);

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Discover People', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 44,
              decoration: GlassTheme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Search users...',
                        hintStyle: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textMuted, size: 18),
                    ),
                ],
              ),
            ),
          ),

          // Users list
          Expanded(
            child: allUsers.when(
              loading: () => ShimmerLoader.list(count: 6),
              error: (e, _) => Center(
                child: Text('Error: $e', style: AppTextStyles.caption),
              ),
              data: (users) {
                final sentUids = sentRequests.valueOrNull ?? [];
                final blocked = blockedUsers.valueOrNull ?? [];
                final friends = friendsList.valueOrNull
                        ?.map((u) => u.uid)
                        .toList() ??
                    [];

                // Filter: exclude blocked users, apply search
                var filtered = users
                    .where((u) => !blocked.contains(u.uid))
                    .where((u) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return u.name.toLowerCase().contains(q) ||
                      u.email.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded,
                            color: AppColors.aquaCore.withValues(alpha: 0.3),
                            size: 64),
                        const SizedBox(height: 12),
                        Text('No users found', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  );
                }

                return AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final user = filtered[i];
                      final isFriend = friends.contains(user.uid);
                      final isRequestSent = sentUids.contains(user.uid);

                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 450),
                        child: SlideAnimation(
                          verticalOffset: 50,
                          curve: Curves.easeOutBack,
                          child: FadeInAnimation(
                            child: _UserTile(
                              user: user,
                              isFriend: isFriend,
                              isRequestSent: isRequestSent,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual user tile in discovery list
class _UserTile extends ConsumerWidget {
  final UserModel user;
  final bool isFriend;
  final bool isRequestSent;

  const _UserTile({
    required this.user,
    required this.isFriend,
    required this.isRequestSent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AquaAvatar(
              imageUrl: user.photoUrl,
              name: user.name,
              size: 44,
              showOnlineDot: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: AppTextStyles.headingSmall
                        .copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildActionButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    if (isFriend) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.onlineGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.onlineGreen.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          'Friends',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onlineGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isRequestSent) {
      return WaterRippleEffect(
        onTap: () async {
          final service = ref.read(friendsServiceProvider);
          await service.cancelFriendRequest(user.uid);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.glassPanel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(
            'Requested',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.lightWave,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return WaterRippleEffect(
      onTap: () async {
        final service = ref.read(friendsServiceProvider);
        await service.sendFriendRequest(user.uid);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.aquaCore.withValues(alpha: 0.25),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          AppStrings.addFriend,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
