import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
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
  String _memberSearchQuery = '';

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

                    // ─── Invite Link Section ──────────────
                    if (isAdmin) ...[
                      _buildInviteLinkSection(groupSnap.data),
                      _buildAdminSettingsSection(groupSnap.data),
                    ],

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

                    // Members search input
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: TextField(
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search members...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onChanged: (val) {
                            setState(() {
                              _memberSearchQuery = val;
                            });
                          },
                        ),
                      ),
                    ),

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
                        final filteredList = list
                            .where((m) => m.name.toLowerCase().contains(_memberSearchQuery.toLowerCase()))
                            .toList();

                        return Column(
                          children: List.generate(filteredList.length, (i) {
                            final member = filteredList[i];
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
                                            value: 'mute',
                                            child: Text('Mute / Restrict',
                                                style: AppTextStyles.body.copyWith(fontSize: 13)),
                                          ),
                                          if (isMemberAdmin)
                                            PopupMenuItem(
                                              value: 'admin_permissions',
                                              child: Text('Admin Permissions',
                                                  style: AppTextStyles.body.copyWith(fontSize: 13)),
                                            ),
                                          PopupMenuItem(
                                            value: 'ban',
                                            child: Text('Ban from Group',
                                                style: AppTextStyles.body.copyWith(
                                                  fontSize: 13,
                                                  color: AppColors.errorRed,
                                                )),
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

                    // Mute Group Toggle
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseService.firestore
                          .collection('users')
                          .doc(myUid)
                          .snapshots(),
                      builder: (ctx, userSnap) {
                        final mutedChats = Map<String, dynamic>.from(
                            userSnap.data?.data()?['mutedChats'] as Map? ?? {});
                        bool isMuted = false;
                        if (mutedChats.containsKey(widget.groupId)) {
                          final expiryStr = mutedChats[widget.groupId] as String?;
                          if (expiryStr == 'always') {
                            isMuted = true;
                          } else if (expiryStr != null) {
                            final expiry = DateTime.tryParse(expiryStr);
                            if (expiry != null && expiry.isAfter(DateTime.now())) {
                              isMuted = true;
                            }
                          }
                        }

                        return GlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 20),
                          child: SwitchListTile(
                            title: const Text('Mute Notifications',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                isMuted ? 'Muted' : 'Unmuted',
                                style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            value: isMuted,
                            activeColor: AppColors.aquaCore,
                            inactiveTrackColor: Colors.white10,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val) {
                                NotificationService.showMuteDialog(context, widget.groupId);
                              } else {
                                NotificationService.unmuteChat(widget.groupId);
                              }
                            },
                          ),
                        );
                      },
                    ),

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
        case 'mute':
          _showMuteDialog(uid, name);
          break;
        case 'admin_permissions':
          _showAdminPermissionsDialog(uid, name);
          break;
        case 'ban':
          _confirmBan(uid, name);
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

  // ─── Invite Link / QR Section ─────────────────────────

  Widget _buildInviteLinkSection(DocumentSnapshot<Map<String, dynamic>>? groupDoc) {
    final inviteCode = groupDoc?.data()?['inviteCode'] as String?;
    final inviteLink = inviteCode != null
        ? 'https://ripple.app/join/$inviteCode'
        : null;

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: AppColors.aquaCore, size: 18),
              const SizedBox(width: 8),
              Text('Invite Link',
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
              const Spacer(),
              if (inviteCode == null)
                GestureDetector(
                  onTap: () => _generateInviteCode(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Generate',
                        style: AppTextStyles.label.copyWith(fontSize: 12)),
                  ),
                ),
            ],
          ),

          if (inviteCode != null) ...[
            const SizedBox(height: 14),

            // QR Code
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: inviteLink!,
                  version: QrVersions.auto,
                  size: 140,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Invite code display
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  inviteLink,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.aquaCyan,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _inviteButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: inviteLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied! 📋')),
                    );
                  },
                ),
                const SizedBox(width: 12),
                _inviteButton(
                  icon: Icons.share_rounded,
                  label: 'Share',
                  onTap: () => Share.share(
                    'Join my group on Ripple!\n$inviteLink',
                  ),
                ),
                const SizedBox(width: 12),
                _inviteButton(
                  icon: Icons.refresh_rounded,
                  label: 'Reset',
                  onTap: () => _generateInviteCode(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminSettingsSection(DocumentSnapshot<Map<String, dynamic>>? groupDoc) {
    final onlyAdminsCanMessage = groupDoc?.data()?['onlyAdminsCanMessage'] as bool? ?? false;

    return GlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_rounded, color: AppColors.aquaCore, size: 18),
              const SizedBox(width: 8),
              Text('Group Settings',
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Only Admins Can Message',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Restrict messaging to group administrators only',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: onlyAdminsCanMessage,
            activeColor: AppColors.aquaCore,
            inactiveTrackColor: Colors.white10,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) async {
              try {
                await FirebaseService.firestore
                    .collection('groups')
                    .doc(widget.groupId)
                    .update({'onlyAdminsCanMessage': val});
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update group setting: $e')),
                  );
                }
              }
            },
          ),
          const Divider(color: Colors.white12, height: 16),
          // Slow Mode Setting
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Slow Mode',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Limit how frequently members can send messages',
                          style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                DropdownButton<int>(
                  value: (groupDoc?.data()?['slowModeSeconds'] as num?)?.toInt() ?? 0,
                  dropdownColor: const Color(0xFF0E1928),
                  style: const TextStyle(color: AppColors.aquaCore, fontSize: 12, fontWeight: FontWeight.bold),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Off')),
                    DropdownMenuItem(value: 10, child: Text('10s')),
                    DropdownMenuItem(value: 30, child: Text('30s')),
                    DropdownMenuItem(value: 60, child: Text('1 min')),
                    DropdownMenuItem(value: 300, child: Text('5 min')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(groupServiceProvider).setSlowMode(widget.groupId, val);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 16),
          // Require Admin Approval
          SwitchListTile(
            title: const Text('Require Admin Approval',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('New members joining via invite link must be approved by an admin',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: groupDoc?.data()?['requiresApproval'] == true,
            activeColor: AppColors.aquaCore,
            inactiveTrackColor: Colors.white10,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              ref.read(groupServiceProvider).setRequiresApproval(widget.groupId, val);
            },
          ),
          const Divider(color: Colors.white12, height: 16),
          // Pending Join Requests
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseService.firestore
                .collection('groups')
                .doc(widget.groupId)
                .collection('join_requests')
                .snapshots(),
            builder: (ctx, reqSnap) {
              final count = reqSnap.data?.docs.length ?? 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_outlined, color: AppColors.aquaCore),
                title: const Text('Join Requests',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('$count pending applicant${count == 1 ? "" : "s"}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: count > 0 ? AppColors.aquaCore : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count > 0 ? '$count New' : 'View',
                    style: TextStyle(
                      color: count > 0 ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () => _showJoinRequestsSheet(reqSnap.data?.docs ?? []),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _inviteButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.aquaCore.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.aquaCore.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.aquaCore, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: AppColors.aquaCore, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _generateInviteCode() async {
    try {
      final random = Random.secure();
      final code = List.generate(8, (_) {
        const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
        return chars[random.nextInt(chars.length)];
      }).join();

      await FirebaseService.firestore
          .collection('groups')
          .doc(widget.groupId)
          .update({'inviteCode': code});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite link generated! 🔗')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  // ── SUPERGROUP GOVERNANCE HELPERS ──────────────────────

  void _showMuteDialog(String uid, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1928),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mute / Restrict $name', style: AppTextStyles.headingSmall),
              const SizedBox(height: 8),
              const Text(
                'Select duration for muting this member:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time_rounded, color: AppColors.aquaCore),
                title: const Text('1 Hour', style: TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(groupServiceProvider).muteMember(
                        widget.groupId,
                        uid,
                        duration: const Duration(hours: 1),
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time_rounded, color: AppColors.aquaCore),
                title: const Text('8 Hours', style: TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(groupServiceProvider).muteMember(
                        widget.groupId,
                        uid,
                        duration: const Duration(hours: 8),
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time_rounded, color: AppColors.aquaCore),
                title: const Text('24 Hours', style: TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(groupServiceProvider).muteMember(
                        widget.groupId,
                        uid,
                        duration: const Duration(days: 1),
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_clock_rounded, color: Colors.orangeAccent),
                title: const Text('Forever / Indefinitely', style: TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(groupServiceProvider).muteMember(
                        widget.groupId,
                        uid,
                        forever: true,
                      );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_up_rounded, color: Colors.greenAccent),
                title: const Text('Unmute', style: TextStyle(color: Colors.greenAccent)),
                onTap: () {
                  ref.read(groupServiceProvider).unmuteMember(widget.groupId, uid);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminPermissionsDialog(String uid, String name) async {
    final groupDoc = await FirebaseService.firestore.collection('groups').doc(widget.groupId).get();
    final adminPerms = Map<String, dynamic>.from(groupDoc.data()?['adminPermissions'] ?? {});
    final current = Map<String, bool>.from((adminPerms[uid] as Map?)?.map((k, v) => MapEntry(k.toString(), v == true)) ?? {
      'canDeleteMessages': true,
      'canBanUsers': true,
      'canInviteUsers': true,
      'canPinMessages': true,
      'canChangeInfo': true,
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0E1928),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Admin Rights: $name', style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                dense: true,
                title: const Text('Delete Messages', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: current['canDeleteMessages'] ?? true,
                activeColor: AppColors.aquaCore,
                onChanged: (v) => setDialogState(() => current['canDeleteMessages'] = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Ban & Mute Users', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: current['canBanUsers'] ?? true,
                activeColor: AppColors.aquaCore,
                onChanged: (v) => setDialogState(() => current['canBanUsers'] = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Pin Messages', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: current['canPinMessages'] ?? true,
                activeColor: AppColors.aquaCore,
                onChanged: (v) => setDialogState(() => current['canPinMessages'] = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Invite Users', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: current['canInviteUsers'] ?? true,
                activeColor: AppColors.aquaCore,
                onChanged: (v) => setDialogState(() => current['canInviteUsers'] = v ?? false),
              ),
              CheckboxListTile(
                dense: true,
                title: const Text('Change Group Info', style: TextStyle(color: Colors.white, fontSize: 13)),
                value: current['canChangeInfo'] ?? true,
                activeColor: AppColors.aquaCore,
                onChanged: (v) => setDialogState(() => current['canChangeInfo'] = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaCore),
              onPressed: () async {
                await ref.read(groupServiceProvider).updateAdminPermissions(widget.groupId, uid, current);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBan(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1928),
        title: Text('Ban $name?', style: const TextStyle(color: Colors.white)),
        content: Text(
          '$name will be removed from the group and banned from rejoining via invite links.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ban Member', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(groupServiceProvider).banMember(widget.groupId, uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name was banned from the group')),
        );
      }
    }
  }

  void _showJoinRequestsSheet(List<QueryDocumentSnapshot<Map<String, dynamic>>> requests) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1928),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending Join Requests (${requests.length})', style: AppTextStyles.headingSmall),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No pending requests', style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    itemBuilder: (ctx, i) {
                      final req = requests[i].data();
                      final applicantUid = req['applicantUid'] as String? ?? requests[i].id;
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white12,
                          child: Icon(Icons.person, color: Colors.white70),
                        ),
                        title: Text('User $applicantUid', style: const TextStyle(color: Colors.white, fontSize: 13)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                              onPressed: () async {
                                await ref.read(groupServiceProvider).approveJoinRequest(widget.groupId, applicantUid);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: AppColors.errorRed),
                              onPressed: () async {
                                await ref.read(groupServiceProvider).rejectJoinRequest(widget.groupId, applicantUid);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
