import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/l10n.dart';
import '../../../core/theme/theme_provider.dart';

/// Vertical Liquid Glass Navigation Rail for Desktop & Tablet Web viewports.
class LiquidNavbarRailWidget extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> unreadCounts;
  final String? userPhotoUrl;
  final double width;

  const LiquidNavbarRailWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCounts = const [0, 0, 0, 0, 0],
    this.userPhotoUrl,
    this.width = 80,
  });

  static const _activeIcons = [
    Icons.chat_bubble_rounded,
    Icons.circle_notifications_rounded,
    Icons.group_rounded,
    Icons.call_rounded,
    Icons.person_rounded,
  ];

  static const _inactiveIcons = [
    Icons.chat_bubble_outline_rounded,
    Icons.circle_notifications_outlined,
    Icons.group_outlined,
    Icons.call_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(rippleThemeProvider);
    final labels = [
      L10n.s(ref, 'chats'),
      'Status',
      L10n.s(ref, 'groups'),
      L10n.s(ref, 'calls'),
      L10n.s(ref, 'profile'),
    ];

    return Container(
      width: width,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colors.glassSurface,
        border: Border(
          right: BorderSide(
            color: theme.colors.glassBorder,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            right: false,
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Logo Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colors.primary.withOpacity(0.3),
                      width: 1.2,
                    ),
                  ),
                  child: const Center(
                    child: Text('🌊', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(height: 24),

                // Navigation Items
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 4, // Chats, Status, Groups, Calls
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (ctx, i) {
                      final isSelected = currentIndex == i;
                      final unread =
                          i < unreadCounts.length ? unreadCounts[i] : 0;
                      return _buildRailItem(
                        icon: isSelected ? _activeIcons[i] : _inactiveIcons[i],
                        label: labels[i],
                        isSelected: isSelected,
                        unread: unread,
                        primaryColor: theme.colors.primary,
                        unselectedColor: theme.colors.textMuted,
                        onTap: () => onTap(i),
                      );
                    },
                  ),
                ),

                // Profile Item at Bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildProfileRailItem(
                    isSelected: currentIndex == 4,
                    primaryColor: theme.colors.primary,
                    unselectedColor: theme.colors.textMuted,
                    onTap: () => onTap(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required int unread,
    required Color primaryColor,
    required Color unselectedColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: primaryColor.withOpacity(0.4), width: 1.2)
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected ? primaryColor : unselectedColor,
              ),
              if (unread > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRailItem({
    required bool isSelected,
    required Color primaryColor,
    required Color unselectedColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: 'Profile',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? primaryColor : unselectedColor.withOpacity(0.3),
              width: isSelected ? 2.0 : 1.2,
            ),
          ),
          child: ClipOval(
            child: userPhotoUrl != null && userPhotoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: userPhotoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      color: isSelected ? primaryColor : unselectedColor,
                    ),
                  )
                : Icon(
                    Icons.person_rounded,
                    color: isSelected ? primaryColor : unselectedColor,
                  ),
          ),
        ),
      ),
    );
  }
}
