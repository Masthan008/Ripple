import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../../friends/providers/friends_provider.dart';
import '../../auth/models/user_model.dart';
import '../providers/group_provider.dart';

/// Create Group Screen — PRD §6.5
/// Select friends, set group name, and create
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final Set<String> _selectedUids = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedUids.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final service = ref.read(groupServiceProvider);
      await service.createGroup(
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        memberUids: _selectedUids.toList(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsListProvider);

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Create Group', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: WaterRippleEffect(
              onTap: _isCreating ? null : _createGroup,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _nameController.text.trim().isNotEmpty &&
                          _selectedUids.isNotEmpty
                      ? AppColors.buttonGradient
                      : null,
                  color: _nameController.text.trim().isEmpty ||
                          _selectedUids.isEmpty
                      ? AppColors.glassPanel
                      : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Create',
                        style: AppTextStyles.label
                            .copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Group name + description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: GlassTheme.inputDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _nameController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Group Name',
                      hintStyle: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: GlassTheme.inputDecoration(),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _descController,
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Description (optional)',
                      hintStyle: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Selected count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Add Members',
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 14),
                ),
                const SizedBox(width: 8),
                if (_selectedUids.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.aquaCore.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedUids.length} selected',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.aquaCore,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Friends list
          Expanded(
            child: friends.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.aquaCore))),
              error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.caption)),
              data: (friendsList) {
                if (friendsList.isEmpty) {
                  return Center(
                    child: Text('Add friends first to create a group',
                        style: AppTextStyles.bodySmall),
                  );
                }

                return AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: friendsList.length,
                    itemBuilder: (_, i) {
                      final friend = friendsList[i];
                      final isSelected =
                          _selectedUids.contains(friend.uid);

                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 350),
                        child: SlideAnimation(
                          verticalOffset: 30,
                          child: FadeInAnimation(
                            child: _FriendSelectTile(
                              user: friend,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUids.remove(friend.uid);
                                  } else {
                                    _selectedUids.add(friend.uid);
                                  }
                                });
                              },
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

class _FriendSelectTile extends StatelessWidget {
  final UserModel user;
  final bool isSelected;
  final VoidCallback onTap;

  const _FriendSelectTile({
    required this.user,
    required this.isSelected,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              AquaAvatar(
                imageUrl: user.photoUrl,
                name: user.name,
                size: 38,
                showOnlineDot: true,
                isOnline: user.isOnline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(user.name,
                    style: AppTextStyles.body.copyWith(fontSize: 14)),
              ),
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient:
                      isSelected ? AppColors.buttonGradient : null,
                  border: !isSelected
                      ? Border.all(
                          color: AppColors.glassBorder, width: 1.5)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
