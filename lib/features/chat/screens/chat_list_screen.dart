import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/glass_theme.dart';
import '../../../shared/widgets/aqua_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';

/// Home screen with bottom navigation bar — glass style per PRD §4.3
/// Tab stubs for Chats, Groups, Calls, Profile (Phase 2+)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    _ChatsTab(),
    _GroupsTab(),
    _CallsTab(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTheme.blurMedium,
          sigmaY: GlassTheme.blurMedium,
        ),
        child: Container(
          decoration: GlassTheme.bottomNavDecoration(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.chat_bubble_rounded, AppStrings.chats, 0),
                  _buildNavItem(Icons.group_rounded, AppStrings.groups, 1),
                  _buildNavItem(Icons.call_rounded, AppStrings.calls, 2),
                  _buildNavItem(Icons.person_rounded, AppStrings.profile, 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppColors.aquaCore
                  : Colors.white.withValues(alpha: 0.55),
              size: 24,
              shadows: isActive
                  ? [
                      Shadow(
                        color: AppColors.aquaCore.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: isActive
                    ? AppColors.aquaCore
                    : Colors.white.withValues(alpha: 0.55),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w300,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Stubs (Phase 2+) ────────────────────────────────

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action buttons
            Row(
              children: [
                Text(AppStrings.messages, style: AppTextStyles.heading),
                const Spacer(),
                // Friend requests button with badge
                _GlassIconButton(
                  icon: Icons.person_add_rounded,
                  onTap: () => GoRouter.of(context).push('/requests'),
                ),
                const SizedBox(width: 8),
                // Discover people button
                _GlassIconButton(
                  icon: Icons.explore_rounded,
                  onTap: () => GoRouter.of(context).push('/users'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your conversations will appear here',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 24),
            // Search bar stub
            Container(
              height: 44,
              decoration: GlassTheme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: AppColors.textMuted, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Search messages...',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Icon(Icons.water_drop_outlined,
                      color: AppColors.aquaCore.withValues(alpha: 0.3),
                      size: 64),
                  const SizedBox(height: 12),
                  Text(
                    'No conversations yet',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start chatting with friends!',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Small frosted glass icon button for header actions
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.glassPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Icon(icon, color: AppColors.lightWave, size: 18),
      ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(AppStrings.groups, style: AppTextStyles.heading),
                const Spacer(),
                _GlassIconButton(
                  icon: Icons.group_add_rounded,
                  onTap: () => GoRouter.of(context).push('/create-group'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: groups.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                  ),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: AppTextStyles.caption),
                ),
                data: (groupList) {
                  if (groupList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined,
                              color: AppColors.aquaCore.withValues(alpha: 0.3),
                              size: 64),
                          const SizedBox(height: 12),
                          Text('No groups yet', style: AppTextStyles.bodySmall),
                          const SizedBox(height: 4),
                          Text('Tap + to create a group',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: groupList.length,
                    itemBuilder: (_, i) {
                      final group = groupList[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () =>
                              GoRouter.of(context).push('/group-chat?groupId=${group.id}&groupName=${Uri.encodeComponent(group.name)}'),
                          child: GlassCard(
                            borderRadius: 14,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                AquaAvatar(
                                  imageUrl: group.photoUrl,
                                  name: group.name,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(group.name,
                                          style: AppTextStyles.headingSmall
                                              .copyWith(fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text('${group.memberCount} members',
                                          style: AppTextStyles.caption),
                                    ],
                                  ),
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
          ],
        ),
      ),
    );
  }
}

class _CallsTab extends StatelessWidget {
  const _CallsTab();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.calls, style: AppTextStyles.heading),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Icon(Icons.call_outlined,
                      color: AppColors.aquaCore.withValues(alpha: 0.3),
                      size: 64),
                  const SizedBox(height: 12),
                  Text('No call history', style: AppTextStyles.bodySmall),
                  const SizedBox(height: 4),
                  Text('Your calls will appear here',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.profile, style: AppTextStyles.heading),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  // Avatar placeholder
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.aquaGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.aquaCyan.withValues(alpha: 0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  user.when(
                    data: (u) => Column(
                      children: [
                        Text(
                          u?.name ?? 'User',
                          style: AppTextStyles.heading,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          u?.email ?? '',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.aquaCore),
                    ),
                    error: (_, __) => Text(
                      'Error loading profile',
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Sign out button
            Center(
              child: GestureDetector(
                onTap: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Sign Out',
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.errorRed,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
