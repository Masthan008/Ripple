import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/stealth_vault_service.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/aqua_avatar.dart';

/// Military-Grade Stealth Vault (Ghost Mode Chat Isolation)
/// Chats placed here are hidden completely from all main feeds and standard search.
class StealthVaultScreen extends ConsumerStatefulWidget {
  const StealthVaultScreen({super.key});

  static const routePath = '/stealth-vault';

  @override
  ConsumerState<StealthVaultScreen> createState() => _StealthVaultScreenState();
}

class _StealthVaultScreenState extends ConsumerState<StealthVaultScreen> {
  final TextEditingController _passcodeController = TextEditingController();

  Future<void> _showChangePasscodeDialog() async {
    final notifier = ref.read(stealthVaultProvider.notifier);
    final currentCode = await notifier.getSecretCode();
    _passcodeController.text = currentCode;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x330EA5E9)),
        ),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.aquaCore, size: 22),
            SizedBox(width: 10),
            Text('Secret Vault Code', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the code you will type in the Chat Search bar to stealthily reveal this vault.',
              style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passcodeController,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '*7777#',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x330EA5E9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.aquaCore, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newCode = _passcodeController.text.trim();
              if (newCode.isNotEmpty) {
                await notifier.setSecretCode(newCode);
                AppHaptics.success();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Secret code updated to "$newCode"'),
                      backgroundColor: AppColors.onlineGreen,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hiddenChatIds = ref.watch(stealthVaultProvider);
    final myUid = FirebaseService.auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.aquaCore.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.aquaCore.withOpacity(0.3)),
              ),
              child: const Icon(Icons.shield_rounded, color: AppColors.aquaCore, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.s(ref, 'stealthVault'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('Isolated • Encrypted Feed', style: TextStyle(color: AppColors.aquaCore, fontSize: 11)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Secret Dial Code',
            icon: const Icon(Icons.dialpad_rounded, color: Colors.white70),
            onPressed: _showChangePasscodeDialog,
          ),
        ],
      ),
      body: hiddenChatIds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: const Icon(Icons.visibility_off_rounded, color: Color(0xFF64748B), size: 36),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Stealth Vault is Empty',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'To hide any conversation from your main screen and search, long-press the chat and select "Hide in Stealth Vault".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseService.firestore
                  .collection('chats')
                  .where('participants', arrayContains: myUid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.aquaCore));
                }

                final docs = (snapshot.data?.docs ?? [])
                    .where((d) => hiddenChatIds.contains(d.id))
                    .toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No active hidden chats found.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final chatDoc = docs[index];
                    final chatData = chatDoc.data();
                    final chatId = chatDoc.id;
                    final isGroup = chatData['isGroup'] == true;
                    final participants = List<String>.from(chatData['participants'] as List? ?? []);
                    final otherUid = participants.firstWhere((p) => p != myUid, orElse: () => '');

                    String lastMsg = 'No messages';
                    final raw = chatData['lastMessage'];
                    if (raw is Map) {
                      lastMsg = raw['text']?.toString() ?? 'Message';
                    } else if (raw is String) {
                      lastMsg = raw;
                    }

                    if (isGroup) {
                      final groupName = chatData['name'] as String? ?? 'Group';
                      final groupPhoto = chatData['photoUrl'] as String?;
                      return _buildVaultTile(
                        chatId: chatId,
                        name: groupName,
                        photoUrl: groupPhoto,
                        lastMessage: lastMsg,
                        isGroup: true,
                      );
                    }

                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseService.firestore.collection('users').doc(otherUid).get(),
                      builder: (ctx, userSnap) {
                        final uData = userSnap.data?.data();
                        final name = uData?['name'] as String? ?? 'Contact';
                        final photo = uData?['photoUrl'] as String?;

                        return _buildVaultTile(
                          chatId: chatId,
                          name: name,
                          photoUrl: photo,
                          lastMessage: lastMsg,
                          isGroup: false,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildVaultTile({
    required String chatId,
    required String name,
    required String? photoUrl,
    required String lastMessage,
    required bool isGroup,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x260EA5E9)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: AquaAvatar(
          imageUrl: photoUrl,
          name: name,
          size: 44,
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
        ),
        trailing: IconButton(
          tooltip: 'Unhide to Main Feed',
          icon: const Icon(Icons.visibility_rounded, color: AppColors.aquaCore, size: 20),
          onPressed: () async {
            AppHaptics.mediumTap();
            await ref.read(stealthVaultProvider.notifier).unhideChat(chatId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$name" restored to main chat list.'),
                  backgroundColor: AppColors.onlineGreen,
                ),
              );
            }
          },
        ),
        onTap: () {
          AppHaptics.selectionTick();
          GoRouter.of(context).push('/chat/$chatId');
        },
      ),
    );
  }
}
