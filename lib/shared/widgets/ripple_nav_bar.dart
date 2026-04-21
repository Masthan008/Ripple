import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_provider.dart';

/// Telegram-style bottom navbar with animated pill indicator,
/// unread badges, and frosted glass background.
/// Fully theme-aware — adapts to dark and light themes.
class RippleNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> unreadCounts;
  final String? userPhotoUrl;

  const RippleNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCounts = const [0, 0, 0, 0, 0, 0],
    this.userPhotoUrl,
  });

  @override
  ConsumerState<RippleNavBar> createState() => _RippleNavBarState();
}

class _RippleNavBarState extends ConsumerState<RippleNavBar>
    with TickerProviderStateMixin {
  late AnimationController _pillController;
  late Animation<double> _pillScale;

  static const _labels = ['Chats', 'Status', 'Groups', 'Calls', 'AI', 'Profile'];

  static const _activeIcons = [
    Icons.chat_bubble_rounded,
    Icons.circle_notifications_rounded,
    Icons.group_rounded,
    Icons.call_rounded,
    Icons.smart_toy_rounded,
    Icons.person_rounded,
  ];

  static const _inactiveIcons = [
    Icons.chat_bubble_outline_rounded,
    Icons.circle_notifications_outlined,
    Icons.group_outlined,
    Icons.call_outlined,
    Icons.smart_toy_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pillScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.easeOut),
    );
    _pillController.forward();
  }

  @override
  void didUpdateWidget(covariant RippleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _pillController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final theme = ref.watch(rippleThemeProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: _buildBarContent(bottomPad, theme),
    );
  }

  Widget _buildBarContent(double bottomPad, dynamic theme) {
    final content = Container(
      height: 72 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colors.surface.withOpacity(theme.isDark ? 0.95 : 0.92),
        border: Border(
          top: BorderSide(
            color: theme.colors.glassBorder,
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: theme.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Row(
        children: List.generate(6, (i) => Expanded(child: _buildTab(i, theme))),
      ),
    );

    if (kIsWeb) return content;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: content,
    );
  }

  Widget _buildTab(int index, dynamic theme) {
    final isActive = widget.currentIndex == index;
    final unread = index < widget.unreadCounts.length
        ? widget.unreadCounts[index]
        : 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTap(index),
      child: ClipRect(
        child: SizedBox(
          height: 72,
          child: Center(
            child: isActive
                ? ScaleTransition(
                    scale: _pillScale,
                    child: _buildActivePill(index, unread, theme),
                  )
                : _buildInactiveItem(index, unread, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePill(int index, int unread, dynamic theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(index, true, unread, theme),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              _labels[index],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: theme.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveItem(int index, int unread, dynamic theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(index, false, unread, theme),
        const SizedBox(height: 4),
        Text(
          _labels[index],
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: theme.colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(int index, bool isActive, int unread, dynamic theme) {
    Widget icon;
    if (index == 5 && isActive && widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colors.primary,
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: widget.userPhotoUrl!,
            width: 19,
            height: 19,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Icon(
              _activeIcons[index],
              color: theme.colors.primary,
              size: 18,
            ),
          ),
        ),
      );
    } else {
      icon = Icon(
        isActive ? _activeIcons[index] : _inactiveIcons[index],
        color: isActive
            ? theme.colors.primary
            : theme.colors.textMuted,
        size: 20,
      );
    }

    if (unread <= 0) return icon;

    // Badge
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -4,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: unread > 9 ? 4 : 0,
            ),
            constraints: const BoxConstraints(
              minWidth: 14,
              minHeight: 14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colors.primary, theme.colors.secondary],
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: GoogleFonts.dmSans(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}