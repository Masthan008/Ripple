import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
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
/// Button state is 100% stream-derived (from parent props).
/// Only `_isLoading` is local — used for the spinner during writes.
class _UserTile extends ConsumerStatefulWidget {
  final UserModel user;
  final bool isFriend;
  final bool isRequestSent;

  const _UserTile({
    required this.user,
    required this.isFriend,
    required this.isRequestSent,
  });

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _isLoading = false;

  Future<void> _sendRequest() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(friendsServiceProvider);
      await service.sendFriendRequest(widget.user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(friendsServiceProvider);
      await service.cancelFriendRequest(widget.user.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFriendsOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.user.name,
              style: AppTextStyles.headingSmall,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.person_remove_rounded,
                  color: AppColors.warningAmber),
              title: Text('Unfriend',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.warningAmber)),
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(friendsServiceProvider)
                      .unfriend(widget.user.uid);
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.block_rounded, color: AppColors.errorRed),
              title: Text('Block',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.errorRed)),
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(friendsServiceProvider)
                      .blockUser(widget.user.uid);
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AquaAvatar(
              imageUrl: widget.user.photoUrl,
              name: widget.user.name,
              size: 44,
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
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    // State 4: Loading — spinner while async write in progress
    if (_isLoading) {
      return Container(
        width: 90,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.glassPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
            ),
          ),
        ),
      );
    }

    // State 3: Friends — green border, checkmark
    if (widget.isFriend) {
      return GestureDetector(
        onTap: _showFriendsOptions,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.onlineGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.onlineGreen.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  color: AppColors.onlineGreen, size: 14),
              const SizedBox(width: 4),
              Text(
                'Friends',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onlineGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State 2: Request Sent — outlined with clock icon
    if (widget.isRequestSent) {
      return GestureDetector(
        onTap: _cancelRequest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.glassPanel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded,
                  color: AppColors.lightWave, size: 14),
              const SizedBox(width: 4),
              Text(
                'Requested',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.lightWave,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // State 1: Add Friend — cyan gradient button
    return GestureDetector(
      onTap: _sendRequest,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_rounded,
                color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              AppStrings.addFriend,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

