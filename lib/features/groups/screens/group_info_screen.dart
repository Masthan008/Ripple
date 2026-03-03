import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/water_ripple_painter.dart';
import '../../auth/models/user_model.dart';
import '../providers/group_provider.dart';

/// Group Info / Admin Screen — PRD §6.6
/// View members, promote/demote admins, remove members, leave/delete group
class GroupInfoScreen extends ConsumerWidget {
  final String groupId;
  final String groupName;
  final String? groupPhoto;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupPhoto,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(groupId));
    final myUid = ref.read(groupServiceProvider).myUid;

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Group Info', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Group avatar & name
            Center(
              child: Column(
                children: [
                  AquaAvatar(
                    imageUrl: groupPhoto,
                    name: groupName,
                    size: 80,
                  ),
                  const SizedBox(height: 14),
                  Text(groupName, style: AppTextStyles.heading),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Members section
            Row(
              children: [
                Text('Members',
                    style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
                const Spacer(),
                members.when(
                  data: (list) => Text('${list.length}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.aquaCore)),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Members list
            members.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                ),
              ),
              error: (e, _) =>
                  Text('Error: $e', style: AppTextStyles.caption),
              data: (list) {
                return AnimationLimiter(
                  child: Column(
                    children: List.generate(list.length, (i) {
                      final member = list[i];
                      final isMe = member.uid == myUid;
                      // Check admin status from provider
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 350),
                        child: SlideAnimation(
                          verticalOffset: 30,
                          child: FadeInAnimation(
                            child: _MemberTile(
                              user: member,
                              isMe: isMe,
                              groupId: groupId,
                              myUid: myUid,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Leave group / Delete group
            WaterRippleEffect(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF0E1928),
                    title: Text('Leave Group?',
                        style: AppTextStyles.heading.copyWith(fontSize: 18)),
                    content: Text(
                      'You will no longer receive messages from this group.',
                      style: AppTextStyles.body,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Leave',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.errorRed)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(groupServiceProvider).leaveGroup(groupId);
                  if (context.mounted) {
                    Navigator.of(context)
                      ..pop() // close info
                      ..pop(); // close chat
                  }
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Leave Group',
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.errorRed),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final UserModel user;
  final bool isMe;
  final String groupId;
  final String myUid;

  const _MemberTile({
    required this.user,
    required this.isMe,
    required this.groupId,
    required this.myUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMe ? '${user.name} (You)' : user.name,
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Text(user.email,
                      style: AppTextStyles.caption.copyWith(fontSize: 10)),
                ],
              ),
            ),
            // Admin actions popup (only for non-self members)
            if (!isMe)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted, size: 18),
                color: const Color(0xFF0E1928),
                onSelected: (action) async {
                  final service = ref.read(groupServiceProvider);
                  switch (action) {
                    case 'make_admin':
                      await service.makeAdmin(groupId, user.uid);
                      break;
                    case 'remove_admin':
                      await service.removeAdmin(groupId, user.uid);
                      break;
                    case 'remove':
                      await service.removeMember(groupId, user.uid);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'make_admin',
                    child: Text('Make Admin',
                        style: AppTextStyles.body.copyWith(fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'remove_admin',
                    child: Text('Remove Admin',
                        style: AppTextStyles.body.copyWith(fontSize: 13)),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from Group',
                        style: AppTextStyles.body
                            .copyWith(fontSize: 13, color: AppColors.errorRed)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
