import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firebase_service.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/models/user_model.dart';
import '../../friends/providers/friends_provider.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  Map<String, bool> _settings = {
    'showOnlineStatus': true,
    'showLastSeen': true,
    'readReceipts': true,
    'allowFriendRequests': true,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseService.firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['privacySettings'] != null) {
        final data = Map<String, bool>.from(doc.data()!['privacySettings']);
        setState(() => _settings = {..._settings, ...data});
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() => _settings[key] = value);
    try {
      final uid = FirebaseService.auth.currentUser?.uid;
      if (uid == null) return;
      await FirebaseService.firestore.collection('users').doc(uid).update({
        'privacySettings.$key': value,
      });
    } catch (e) {
      setState(() => _settings[key] = !value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.'),
              backgroundColor: AppColors.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedUsers = ref.watch(blockedUsersProvider);

    final toggles = [
      _ToggleItem('Show Online Status', 'showOnlineStatus', Icons.visibility_outlined),
      _ToggleItem('Show Last Seen', 'showLastSeen', Icons.schedule_outlined),
      _ToggleItem('Read Receipts', 'readReceipts', Icons.done_all_rounded),
      _ToggleItem('Allow Friend Requests', 'allowFriendRequests', Icons.person_add_outlined),
    ];

    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      appBar: AppBar(
        title: Text('Privacy', style: AppTextStyles.heading),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.aquaCore),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.aquaCore)))
          : AnimationLimiter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 450),
                    childAnimationBuilder: (w) => SlideAnimation(
                      verticalOffset: 50,
                      curve: Curves.easeOutBack,
                      child: FadeInAnimation(child: w),
                    ),
                    children: [
                      _sectionHeader('Privacy Settings'),
                      const SizedBox(height: 8),
                      ...toggles.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassCard(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(t.icon, color: AppColors.aquaCore, size: 22),
                              const SizedBox(width: 14),
                              Expanded(child: Text(t.label, style: AppTextStyles.body.copyWith(fontSize: 14))),
                              CupertinoSwitch(
                                value: _settings[t.key] ?? true,
                                onChanged: (v) => _updateSetting(t.key, v),
                                activeTrackColor: AppColors.aquaCore,
                              ),
                            ],
                          ),
                        ),
                      )),
                      const SizedBox(height: 20),
                      _sectionHeader('Blocked Users'),
                      const SizedBox(height: 8),
                      blockedUsers.when(
                        loading: () => const Center(child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(AppColors.aquaCore))),
                        error: (e, _) => Text('Error: $e', style: AppTextStyles.caption),
                        data: (blocked) {
                          if (blocked.isEmpty) {
                            return GlassCard(
                              borderRadius: 14,
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.block_rounded,
                                        color: AppColors.textMuted, size: 40),
                                    const SizedBox(height: 8),
                                    Text('No blocked users',
                                        style: AppTextStyles.caption),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: blocked.map((uid) => _BlockedUserTile(uid: uid)).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title.toUpperCase(),
    style: AppTextStyles.caption.copyWith(
      fontSize: 11, fontWeight: FontWeight.w600,
      letterSpacing: 1.2, color: AppColors.aquaCore.withValues(alpha: 0.7),
    ),
  );
}

class _BlockedUserTile extends ConsumerWidget {
  final String uid;
  const _BlockedUserTile({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: FirebaseService.usersCollection.doc(uid).get(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final user = UserModel.fromFirestore(snap.data!);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            borderRadius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                AquaAvatar(imageUrl: user.photoUrl, name: user.name, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text(user.name, style: AppTextStyles.body.copyWith(fontSize: 14))),
                GestureDetector(
                  onTap: () async {
                    try {
                      await ref.read(friendsServiceProvider).unblockUser(uid);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('${user.name} unblocked'),
                              backgroundColor: AppColors.onlineGreen),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Something went wrong'),
                              backgroundColor: AppColors.errorRed),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Text('Unblock',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.errorRed, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToggleItem {
  final String label;
  final String key;
  final IconData icon;
  const _ToggleItem(this.label, this.key, this.icon);
}
