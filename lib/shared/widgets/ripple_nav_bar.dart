import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_provider.dart';

/// Telegram-style floating pill navbar with frosted glass,
/// animated pill indicator, unread badges, and theme awareness.
/// Redesigned as a floating capsule with rounded ends.
class RippleNavBar extends ConsumerStatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<int> unreadCounts;
  final String? userPhotoUrl;

  const RippleNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCounts = const [0, 0, 0, 0],
    this.userPhotoUrl,
  });

  @override
  ConsumerState<RippleNavBar> createState() => _RippleNavBarState();
}

class _RippleNavBarState extends ConsumerState<RippleNavBar>
    with TickerProviderStateMixin {
  late AnimationController _pillController;
  late Animation<double> _pillScale;

  static const _labels = ['Chats', 'Status', 'AI', 'Profile'];

  static const _activeIcons = [
    Icons.chat_bubble_rounded,
    Icons.circle_notifications_rounded,
    Icons.smart_toy_rounded,
    Icons.person_rounded,
  ];

  static const _inactiveIcons = [
    Icons.chat_bubble_outline_rounded,
    Icons.circle_notifications_outlined,
    Icons.smart_toy_outlined,
    Icons.person_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pillScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pillController, curve: Curves.easeOutCubic),
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

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPad + 10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _buildBarContent(theme),
      ),
    );
  }

  Widget _buildBarContent(dynamic theme) {
    final content = Container(
      height: 64,
      decoration: BoxDecoration(
        color: theme.isDark
            ? theme.colors.surface.withOpacity(0.88)
            : Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.isDark
              ? theme.colors.glassBorder.withOpacity(0.18)
              : Colors.black.withOpacity(0.06),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.isDark ? 0.35 : 0.10),
            blurRadius: 24,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          if (theme.isDark)
            BoxShadow(
              color: theme.colors.primary.withOpacity(0.06),
              blurRadius: 40,
              offset: const Offset(0, -2),
              spreadRadius: 0,
            ),
        ],
      ),
      child: Row(
        children: List.generate(4, (i) => Expanded(child: _buildTab(i, theme))),
      ),
    );

    if (kIsWeb) return content;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
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
      child: SizedBox(
        height: 64,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeIn,
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
      key: ValueKey('active_$index'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colors.primary.withOpacity(0.18),
            theme.colors.secondary.withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colors.primary.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(index, true, unread, theme),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _labels[index],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colors.primary,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveItem(int index, int unread, dynamic theme) {
    return Column(
      key: ValueKey('inactive_$index'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(index, false, unread, theme),
        const SizedBox(height: 3),
        Text(
          _labels[index],
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: theme.isDark
                ? theme.colors.textMuted.withOpacity(0.6)
                : Colors.black45,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(int index, bool isActive, int unread, dynamic theme) {
    Widget icon;
    if (index == 3 && widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? theme.colors.primary
                : theme.colors.textMuted.withOpacity(0.3),
            width: isActive ? 2 : 1,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: widget.userPhotoUrl!,
            width: 18,
            height: 18,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Icon(
              _activeIcons[index],
              color: isActive ? theme.colors.primary : theme.colors.textMuted,
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
            : theme.isDark
                ? theme.colors.textMuted.withOpacity(0.6)
                : Colors.black38,
        size: 21,
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
          top: -5,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: unread > 9 ? 4 : 0,
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colors.primary, theme.colors.secondary],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.colors.primary.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Center(
              child: Text(
                unread > 99 ? '99+' : '$unread',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
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