import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/water_ripple_painter.dart';

import '../../friends/providers/friends_provider.dart';
import '../providers/group_provider.dart';

/// Group Info / Admin Screen — PRD §6.6
/// View/edit group profile, manage members, admin controls, leave/delete
class GroupInfoScreen extends ConsumerStatefulWidget {
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
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _isEditingName = false;
  bool _isEditingDesc = false;
  bool _isUploadingPhoto = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.groupName);
    _descCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final myUid = ref.read(groupServiceProvider).myUid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .snapshots(),
      builder: (ctx, groupSnap) {
        final admins = <String>[];
        String currentName = widget.groupName;
        String? currentDesc;
        String? currentPhoto = widget.groupPhoto;
        Map<String, dynamic> memberPermissions = {};

        if (groupSnap.hasData && groupSnap.data!.exists) {
          final gData = groupSnap.data!.data()!;
          admins.addAll(List<String>.from(gData['admins'] ?? []));
          currentName = gData['name'] ?? widget.groupName;
          currentDesc = gData['description'];
          currentPhoto = gData['photoUrl'];
          memberPermissions =
              Map<String, dynamic>.from(gData['memberPermissions'] ?? {});
        }

        final isAdmin = admins.contains(myUid);
        final myPerms =
            Map<String, dynamic>.from(memberPermissions[myUid] ?? {});
        final canEdit = isAdmin || (myPerms['canEditInfo'] == true);
        final canAdd = isAdmin || (myPerms['canAddMembers'] == true);

        return Scaffold(
          backgroundColor: AppColors.abyssBackground,
          appBar: AppBar(
            title: Text('Group Info', style: AppTextStyles.heading),
            backgroundColor: Colors.transparent,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimationLimiter(
              child: Column(
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 350),
                  childAnimationBuilder: (w) => SlideAnimation(
                    verticalOffset: 30,
                    child: FadeInAnimation(child: w),
                  ),
                  children: [
                    const SizedBox(height: 16),

                    // ─── Group Profile ───────────────────
                    Center(
                      child: Column(
                        children: [
                          // Group photo with camera overlay
                          Stack(
                            children: [
                              if (_isUploadingPhoto)
                                const SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                        AppColors.aquaCore),
                                  ),
                                )
                              else
                                AquaAvatar(
                                  imageUrl: currentPhoto,
                                  name: currentName,
                                  size: 80,
                                ),
                              if (canEdit && !_isUploadingPhoto)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () =>
                                        _pickAndUploadPhoto(widget.groupId),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.aquaCore,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.abyssBackground,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Editable name
                          _isEditingName
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 200,
                                      child: TextField(
                                        controller: _nameCtrl,
                                        style: AppTextStyles.heading,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_rounded,
                                          color: AppColors.onlineGreen),
                                      onPressed: () async {
                                        final name = _nameCtrl.text.trim();
                                        if (name.isNotEmpty) {
                                          try {
                                            await ref
                                                .read(groupServiceProvider)
                                                .updateGroup(widget.groupId,
                                                    name: name);
                                            if (!mounted) return;
                                            // ignore: use_build_context_synchronously
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Group name updated'),
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            // ignore: use_build_context_synchronously
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor:
                                                    AppColors.errorRed,
                                              ),
                                            );
                                          }
                                        }
                                        setState(
                                            () => _isEditingName = false);
                                      },
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(currentName,
                                          style: AppTextStyles.heading),
                                    ),
                                    if (canEdit)
                                      IconButton(
                                        icon: Icon(Icons.edit_rounded,
                                            color: AppColors.aquaCore,
                                            size: 18),
                                        onPressed: () => setState(
                                            () => _isEditingName = true),
                                      ),
                                  ],
                                ),

                          // Description
                          if (_isEditingDesc)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _descCtrl,
                                      style: AppTextStyles.caption,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        hintText: 'Group description',
                                        hintStyle: TextStyle(
                                            color: AppColors.textMuted),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check_rounded,
                                        color: AppColors.onlineGreen),
                                    onPressed: () async {
                                      try {
                                        await ref
                                            .read(groupServiceProvider)
                                            .updateGroup(widget.groupId,
                                                description:
                                                    _descCtrl.text.trim());
                                      } catch (e) {
                                        if (!mounted) return;
                                        // ignore: use_build_context_synchronously
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor:
                                                AppColors.errorRed,
                                          ),
                                        );
                                      }
                                      setState(
                                          () => _isEditingDesc = false);
                                    },
                                  ),
                                ],
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: canEdit
                                  ? () {
                                      _descCtrl.text = currentDesc ?? '';
                                      setState(
                                          () => _isEditingDesc = true);
                                    }
                                  : null,
                              child: Text(
                                currentDesc ??
                                    (canEdit
                                        ? 'Add description'
                                        : 'No description'),
                                style: AppTextStyles.caption.copyWith(
                                  color: currentDesc != null
                                      ? AppColors.textMuted
                                      : AppColors.aquaCore
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                            ),

                          const SizedBox(height: 6),

                          // Member count
                          members.when(
                            data: (list) => Text(
                              '${list.length} members',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ─── Members Section ─────────────────
                    Row(
                      children: [
                        Text('Members',
                            style: AppTextStyles.headingSmall
                                .copyWith(fontSize: 14)),
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

                    // Add Members button (admin or canAdd)
                    if (canAdd)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: WaterRippleEffect(
                          onTap: () => _showAddMembersSheet(context),
                          child: GlassCard(
                            borderRadius: 14,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.aquaCore
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.person_add_rounded,
                                      color: AppColors.aquaCore, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text('Add Members',
                                    style: AppTextStyles.body.copyWith(
                                        fontSize: 14,
                                        color: AppColors.aquaCore)),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Members list
                    members.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.aquaCore),
                        ),
                      ),
                      error: (e, _) => Text('Error: $e',
                          style: AppTextStyles.caption),
                      data: (list) {
                        return Column(
                          children: List.generate(list.length, (i) {
                            final member = list[i];
                            final isMe = member.uid == myUid;
                            final isMemberAdmin =
                                admins.contains(member.uid);
                            final mPerms = Map<String, dynamic>.from(
                                memberPermissions[member.uid] ?? {});
                            final hasCanEdit =
                                mPerms['canEditInfo'] == true;
                            final hasCanAdd =
                                mPerms['canAddMembers'] == true;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: GlassCard(
                                borderRadius: 14,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        AquaAvatar(
                                          imageUrl: member.photoUrl,
                                          name: member.name,
                                          size: 38,
                                          showOnlineDot: true,
                                          isOnline: member.isOnline,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  isMe
                                                      ? '${member.name} (You)'
                                                      : member.name,
                                                  style: AppTextStyles.body
                                                      .copyWith(
                                                          fontSize: 14),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (isMemberAdmin)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.aquaCore
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(8),
                                                  ),
                                                  child: Text('Admin',
                                                      style: AppTextStyles
                                                          .caption
                                                          .copyWith(
                                                        fontSize: 9,
                                                        color: AppColors
                                                            .aquaCore,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      )),
                                                )
                                              else
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.08),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(8),
                                                  ),
                                                  child: Text('Member',
                                                      style: AppTextStyles
                                                          .caption
                                                          .copyWith(
                                                        fontSize: 9,
                                                        color: AppColors
                                                            .textMuted,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      )),
                                                ),
                                            ],
                                          ),
                                          Text(member.email,
                                              style: AppTextStyles.caption
                                                  .copyWith(fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    // Admin controls
                                    if (isAdmin && !isMe)
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                            Icons.more_vert_rounded,
                                            color: AppColors.textMuted,
                                            size: 18),
                                        color:
                                            const Color(0xFF0E1928),
                                        onSelected: (action) =>
                                            _handleMemberAction(
                                                action,
                                                member.uid,
                                                member.name,
                                                isMemberAdmin,
                                                hasCanEdit,
                                                hasCanAdd),
                                        itemBuilder: (_) => [
                                          if (!isMemberAdmin)
                                            PopupMenuItem(
                                              value: 'make_admin',
                                              child: Text('Make Admin',
                                                  style: AppTextStyles.body
                                                      .copyWith(
                                                          fontSize: 13)),
                                            ),
                                          if (isMemberAdmin)
                                            PopupMenuItem(
                                              value: 'remove_admin',
                                              child: Text(
                                                  'Remove Admin',
                                                  style: AppTextStyles.body
                                                      .copyWith(
                                                          fontSize: 13)),
                                            ),
                                          PopupMenuItem(
                                            value: 'toggle_edit',
                                            child: Text(
                                                hasCanEdit
                                                    ? '✓ Can Edit Group Info'
                                                    : 'Can Edit Group Info',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        fontSize: 13)),
                                          ),
                                          PopupMenuItem(
                                            value: 'toggle_add',
                                            child: Text(
                                                hasCanAdd
                                                    ? '✓ Can Add Members'
                                                    : 'Can Add Members',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        fontSize: 13)),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Text(
                                                'Remove from Group',
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.errorRed,
                                                )),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // ─── Leave Group ─────────────────────
                    WaterRippleEffect(
                      onTap: () => _confirmLeave(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color:
                              AppColors.warningAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.warningAmber
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Leave Group',
                            style: AppTextStyles.button
                                .copyWith(color: AppColors.warningAmber),
                          ),
                        ),
                      ),
                    ),

                    // Delete Group (admin only)
                    if (isAdmin) ...[
                      const SizedBox(height: 12),
                      WaterRippleEffect(
                        onTap: () => _confirmDelete(currentName),
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.errorRed
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Delete Group',
                              style: AppTextStyles.button
                                  .copyWith(color: AppColors.errorRed),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(String groupId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final url = await CloudinaryService.uploadImage(File(picked.path));
      if (url != null) {
        await ref
            .read(groupServiceProvider)
            .updateGroup(groupId, photoUrl: url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _handleMemberAction(String action, String uid, String name,
      bool isMemberAdmin, bool hasCanEdit, bool hasCanAdd) async {
    final service = ref.read(groupServiceProvider);
    try {
      switch (action) {
        case 'make_admin':
          await service.makeAdmin(widget.groupId, uid);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name is now an admin')),
          );
          break;
        case 'remove_admin':
          await service.removeAdmin(widget.groupId, uid);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed admin from $name')),
          );
          break;
        case 'toggle_edit':
          await service.toggleCanEditInfo(widget.groupId, uid);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(hasCanEdit
                    ? '$name can no longer edit group info'
                    : '$name can now edit group info')),
          );
          break;
        case 'toggle_add':
          await service.toggleCanAddMembers(widget.groupId, uid);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(hasCanAdd
                    ? '$name can no longer add members'
                    : '$name can now add members')),
          );
          break;
        case 'remove':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF0E1928),
              title: Text('Remove $name?',
                  style: AppTextStyles.heading.copyWith(fontSize: 18)),
              content: Text(
                  'Remove $name from group?',
                  style: AppTextStyles.body),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.textMuted)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Remove',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.errorRed)),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await service.removeMember(widget.groupId, uid);
          }
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  Future<void> _confirmLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E1928),
        title: Text('Leave Group?',
            style: AppTextStyles.heading.copyWith(fontSize: 18)),
        content: Text(
          'Leave ${widget.groupName}?',
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
      try {
        await ref.read(groupServiceProvider).leaveGroup(widget.groupId);
        if (!mounted) return;
        Navigator.of(context)
          ..pop() // close info
          ..pop(); // close chat
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0E1928),
        title: Text('Delete Group?',
            style: AppTextStyles.heading.copyWith(fontSize: 18)),
        content: Text(
          'Delete "$name" permanently? This cannot be undone.',
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
            child: Text('Delete',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(groupServiceProvider).deleteGroup(widget.groupId);
        if (!mounted) return;
        Navigator.of(context)
          ..pop() // close info
          ..pop(); // close chat
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  void _showAddMembersSheet(BuildContext parentContext) {
    final existingMembers =
        ref.read(groupMembersProvider(widget.groupId)).valueOrNull ?? [];
    final existingUids = existingMembers.map((m) => m.uid).toSet();
    final selectedUids = <String>{};

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: AppColors.abyssBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            final friendsAsync = ref.watch(friendsListProvider);

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.85,
              minChildSize: 0.4,
              expand: false,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Add Members',
                          style: AppTextStyles.heading
                              .copyWith(fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('Select friends to add',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 16),
                      Expanded(
                        child: friendsAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                  AppColors.aquaCore),
                            ),
                          ),
                          error: (e, _) => Text('Error: $e',
                              style: AppTextStyles.caption),
                          data: (friends) {
                            final available = friends
                                .where(
                                    (f) => !existingUids.contains(f.uid))
                                .toList();

                            if (available.isEmpty) {
                              return Center(
                                child: Text(
                                    'All friends are already members',
                                    style: AppTextStyles.caption),
                              );
                            }

                            return ListView.builder(
                              controller: scrollCtrl,
                              itemCount: available.length,
                              itemBuilder: (_, i) {
                                final f = available[i];
                                final isSelected =
                                    selectedUids.contains(f.uid);
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: GlassCard(
                                    borderRadius: 12,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          if (isSelected) {
                                            selectedUids.remove(f.uid);
                                          } else {
                                            selectedUids.add(f.uid);
                                          }
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          AquaAvatar(
                                            imageUrl: f.photoUrl,
                                            name: f.name,
                                            size: 36,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(f.name,
                                                style: AppTextStyles.body
                                                    .copyWith(
                                                        fontSize: 14)),
                                          ),
                                          Icon(
                                            isSelected
                                                ? Icons
                                                    .check_circle_rounded
                                                : Icons
                                                    .circle_outlined,
                                            color: isSelected
                                                ? AppColors.aquaCore
                                                : AppColors.textMuted,
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: selectedUids.isNotEmpty
                                ? AppColors.buttonGradient
                                : null,
                            color: selectedUids.isEmpty
                                ? AppColors.glassPanel
                                : null,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ElevatedButton(
                            onPressed: selectedUids.isEmpty
                                ? null
                                : () async {
                                    try {
                                      await ref
                                          .read(groupServiceProvider)
                                          .addMembers(widget.groupId,
                                              selectedUids.toList());
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor:
                                              AppColors.errorRed,
                                        ),
                                      );
                                    }
                                    if (!mounted) return;
                                    // ignore: use_build_context_synchronously
                                    Navigator.pop(ctx2);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              selectedUids.isEmpty
                                  ? 'Select friends'
                                  : 'Add ${selectedUids.length} Member${selectedUids.length > 1 ? "s" : ""}',
                              style: AppTextStyles.button,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
