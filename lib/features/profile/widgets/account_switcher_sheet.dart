import '../../auth/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/account_vault_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';

class AccountSwitcherSheet extends ConsumerStatefulWidget {
  const AccountSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1928),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AccountSwitcherSheet(),
    );
  }

  @override
  ConsumerState<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends ConsumerState<AccountSwitcherSheet> {
  List<SavedAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final list = await AccountVaultService.getSavedAccounts();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Ensure current active user is in the vault
    if (currentUser != null && !list.any((a) => a.uid == currentUser.uid)) {
      final currentAcc = SavedAccount(
        uid: currentUser.uid,
        email: currentUser.email ?? '',
        displayName: currentUser.displayName ?? 'Ripple User',
        photoUrl: currentUser.photoURL,
        phoneNumber: currentUser.phoneNumber,
        lastActive: DateTime.now(),
      );
      await AccountVaultService.saveAccount(currentAcc);
      list.insert(0, currentAcc);
    }

    if (mounted) {
      setState(() {
        _accounts = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Accounts', style: AppTextStyles.headingSmall.copyWith(fontSize: 18)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.aquaCore.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_accounts.length} / 4',
                    style: const TextStyle(
                      color: AppColors.aquaCore,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.aquaCore),
                ),
              )
            else ...[
              // List of accounts
              ..._accounts.map((acc) {
                final isActive = acc.uid == currentUid;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? AppColors.aquaCore.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: AquaAvatar(
                      imageUrl: acc.photoUrl,
                      name: acc.displayName,
                      size: 42,
                    ),
                    title: Text(
                      acc.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      acc.email.isNotEmpty ? acc.email : (acc.phoneNumber ?? ''),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.aquaCore, size: 22)
                        : IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.white30, size: 18),
                            onPressed: () async {
                              await AccountVaultService.removeAccount(acc.uid);
                              _loadAccounts();
                            },
                          ),
                    onTap: () async {
                      if (!isActive) {
                        bool success = false;
                        if (acc.password != null && acc.password!.isNotEmpty) {
                          success = await AccountVaultService.switchAccount(acc);
                        } else {
                          final pwd = await _promptPasswordDialog(context, acc);
                          if (pwd != null && pwd.isNotEmpty) {
                            final updatedAcc = SavedAccount(
                              uid: acc.uid,
                              email: acc.email,
                              displayName: acc.displayName,
                              password: pwd,
                              photoUrl: acc.photoUrl,
                              phoneNumber: acc.phoneNumber,
                              lastActive: DateTime.now(),
                            );
                            await AccountVaultService.saveAccount(updatedAcc);
                            success = await AccountVaultService.switchAccount(updatedAcc);
                          }
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (success) {
                            ref.invalidate(authStateProvider);
                            ref.invalidate(currentUserProvider);
                            context.go('/home');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Switched to ${acc.displayName}'),
                                backgroundColor: AppColors.onlineGreen,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not switch to ${acc.displayName}. Please log in again.'),
                                backgroundColor: AppColors.errorRed,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                );
              }),

              const SizedBox(height: 12),

              // Add Account Button
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/login?addAccount=true');
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: const [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white10,
                        child: Icon(Icons.add_rounded, color: AppColors.aquaCore, size: 22),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Add Another Account',
                        style: TextStyle(
                          color: AppColors.aquaCore,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<String?> _promptPasswordDialog(BuildContext context, SavedAccount acc) async {
    final pwdCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.aquaCore),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.aquaCore),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Switch to ${acc.displayName}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter password for ${acc.email}:', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pwdCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.aquaCore,
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

}
