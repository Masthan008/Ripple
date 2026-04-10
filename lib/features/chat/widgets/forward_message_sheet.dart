import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../models/message_model.dart';
import '../services/message_actions_service.dart';

/// Bottom sheet for forwarding messages to chats and groups
class ForwardMessageSheet extends ConsumerStatefulWidget {
  final MessageModel message;
  final VoidCallback? onDone;

  const ForwardMessageSheet({super.key, required this.message, this.onDone});

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedChatIds = {};
  final Set<String> _selectedGroupIds = {};
  bool _isSending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalSelected => _selectedChatIds.length + _selectedGroupIds.length;

  Future<void> _forward() async {
    if (_totalSelected == 0) return;

    setState(() => _isSending = true);

    try {
      await MessageActionsService.forwardMessage(
        message: widget.message,
        targetChatIds: _selectedChatIds.toList(),
        targetGroupIds: _selectedGroupIds.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.s(ref, 'messageForwarded')),
            backgroundColor: AppColors.aquaCore,
          ),
        );
        widget.onDone?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.s(ref, 'forwardFailed')}: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(
                  L10n.s(ref, 'forwardMessage'),
                  style: AppTextStyles.headingSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: L10n.s(ref, 'searchByName'),
                  hintStyle: const TextStyle(color: Colors.white24),
                  border: InputBorder.none,
                  icon: const Icon(Icons.search, color: Colors.white24),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Chat & Group lists
          Expanded(
            child: ListView(
              children: [
                // Recent Chats Title
                if (_searchQuery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      L10n.s(ref, 'recentChats'),
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.aquaCore,
                      ),
                    ),
                  ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('chats')
                          .where('participants', arrayContains: uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final chats = snapshot.data!.docs;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          chats.map((doc) {
                            final data = doc.data();
                            final chatId = doc.id;
                            final participants = List<String>.from(
                              data['participants'] as List? ?? [],
                            );
                            final otherUid = participants.firstWhere(
                              (p) => p != uid,
                              orElse: () => '',
                            );
                            if (otherUid.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return FutureBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(otherUid)
                                      .get(),
                              builder: (context, userSnap) {
                                final name =
                                    userSnap.data?.data()?['name'] as String? ??
                                    'User';
                                final photo =
                                    userSnap.data?.data()?['photoUrl']
                                        as String?;

                                if (_searchQuery.isNotEmpty &&
                                    !name.toLowerCase().contains(
                                      _searchQuery,
                                    )) {
                                  return const SizedBox.shrink();
                                }

                                final isSelected = _selectedChatIds.contains(
                                  chatId,
                                );

                                return _listTile(
                                  name: name,
                                  photoUrl: photo,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedChatIds.remove(chatId);
                                      } else {
                                        _selectedChatIds.add(chatId);
                                      }
                                    });
                                  },
                                );
                              },
                            );
                          }).toList(),
                    );
                  },
                ),

                // Groups Title
                if (_searchQuery.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Text(
                      L10n.s(ref, 'groups'),
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.aquaCore,
                      ),
                    ),
                  ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('groups')
                          .where('members', arrayContains: uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final groups = snapshot.data!.docs;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          groups.map((doc) {
                            final data = doc.data();
                            final groupId = doc.id;
                            final name = data['name'] as String? ?? 'Group';
                            final photo = data['photoUrl'] as String?;

                            if (_searchQuery.isNotEmpty &&
                                !name.toLowerCase().contains(_searchQuery)) {
                              return const SizedBox.shrink();
                            }

                            final isSelected = _selectedGroupIds.contains(
                              groupId,
                            );

                            return _listTile(
                              name: name,
                              photoUrl: photo,
                              isSelected: isSelected,
                              isGroup: true,
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedGroupIds.remove(groupId);
                                  } else {
                                    _selectedGroupIds.add(groupId);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Forward button
          if (_totalSelected > 0)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _forward,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.aquaCore,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child:
                      _isSending
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            'Forward to $_totalSelected chat(s)',
                            style: AppTextStyles.button,
                          ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.aquaCore.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _listTile({
    required String name,
    String? photoUrl,
    required bool isSelected,
    bool isGroup = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: AquaAvatar(imageUrl: photoUrl, name: name, size: 38),
      title: Text(name, style: AppTextStyles.body.copyWith(fontSize: 14)),
      subtitle:
          isGroup
              ? Text(
                L10n.s(ref, 'group'),
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              )
              : null,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppColors.aquaCore : Colors.transparent,
          border: Border.all(
            color:
                isSelected ? AppColors.aquaCore : Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child:
            isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : null,
      ),
    );
  }
}
