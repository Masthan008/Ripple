import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/utils/l10n.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/theme/theme_provider.dart';

/// Official Liquid Glass Navigation Bar powered by [liquid_glass_widgets: ^1.16.0].
///
/// Features shader-based two-pass Gaussian blur, chromatic aberration,
/// iOS 27 liquid glass material, magic lens masking, jelly physics pill indicator,
/// and content-aware brightness adaptation.
class LiquidNavbarWidget extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> unreadCounts;
  final String? userPhotoUrl;

  final double indicatorWidth;
  final double navbarHeight;
  final double bottomPadding;
  final double horizontalPadding;
  final List<String>? customLabels;
  final List<IconData>? customActiveIcons;
  final List<IconData>? customInactiveIcons;

  const LiquidNavbarWidget({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCounts = const [0, 0, 0, 0, 0],
    this.userPhotoUrl,
    this.indicatorWidth = 64,
    this.navbarHeight = 64,
    this.bottomPadding = 16,
    this.horizontalPadding = 16,
    this.customLabels,
    this.customActiveIcons,
    this.customInactiveIcons,
  });

  List<String> _getLabels(WidgetRef ref) {
    if (customLabels != null) return customLabels!;
    return [
      L10n.s(ref, 'chats'),
      L10n.s(ref, 'status'),
      L10n.s(ref, 'groups'),
      L10n.s(ref, 'calls'),
      L10n.s(ref, 'profile'),
    ];
  }

  static const _defaultActiveIcons = [
    Icons.chat_bubble_rounded,
    Icons.circle_notifications_rounded,
    Icons.group_rounded,
    Icons.call_rounded,
    Icons.person_rounded,
  ];

  static const _defaultInactiveIcons = [
    Icons.chat_bubble_outline_rounded,
    Icons.circle_notifications_outlined,
    Icons.group_outlined,
    Icons.call_outlined,
    Icons.person_outline_rounded,
  ];

  Widget _buildTabIcon(IconData iconData, int unreadCount) {
    final icon = Icon(iconData, size: 24);

    if (unreadCount <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        icon,
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Text(
              unreadCount > 99 ? '99+' : '$unreadCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarIcon(String url, {required bool isSelected, required Color primaryColor}) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? primaryColor : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(
            isSelected ? Icons.person_rounded : Icons.person_outline_rounded,
            size: 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = _getLabels(ref);
    final theme = ref.watch(rippleThemeProvider);

    final activeIcons = customActiveIcons ?? _defaultActiveIcons;
    final inactiveIcons = customInactiveIcons ?? _defaultInactiveIcons;
    final itemCount = labels.length;

    final tabs = List.generate(itemCount, (i) {
      final unread = i < unreadCounts.length ? unreadCounts[i] : 0;
      final isProfileTab = i == itemCount - 1;

      Widget iconWidget;
      Widget activeIconWidget;

      if (isProfileTab && userPhotoUrl != null && userPhotoUrl!.isNotEmpty) {
        iconWidget = _buildAvatarIcon(userPhotoUrl!, isSelected: false, primaryColor: theme.colors.primary);
        activeIconWidget = _buildAvatarIcon(userPhotoUrl!, isSelected: true, primaryColor: theme.colors.primary);
      } else {
        iconWidget = _buildTabIcon(inactiveIcons[i], unread);
        activeIconWidget = _buildTabIcon(activeIcons[i], unread);
      }

      return GlassTab(
        icon: iconWidget,
        activeIcon: activeIconWidget,
        label: labels[i],
        glowColor: theme.colors.primary,
      );
    });

    return GlassTabBar.bottom(
      selectedIndex: currentIndex.clamp(0, itemCount - 1),
      onTabSelected: (index) {
        AppHaptics.selectionTick();
        onTap(index);
      },
      barHeight: navbarHeight,
      horizontalPadding: horizontalPadding,
      verticalPadding: bottomPadding,
      maskingQuality: MaskingQuality.high,
      adaptiveBrightness: true,
      indicatorColor: theme.colors.primary.withValues(alpha: 0.35),
      selectedIconColor: theme.colors.primary,
      unselectedIconColor: theme.colors.textMuted,
      selectedLabelColor: theme.colors.primary,
      unselectedLabelColor: theme.colors.textMuted,
      settings: LiquidGlassSettings.ios27Dark,
      tabs: tabs,
    );
  }
}
