import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Telegram-style bottom navbar with animated pill indicator,
/// unread badges, and frosted glass background.
class RippleNavBar extends StatefulWidget {
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
  State<RippleNavBar> createState() => _RippleNavBarState();
}

class _RippleNavBarState extends State<RippleNavBar>
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

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: _buildBarContent(bottomPad),
    );
  }

  Widget _buildBarContent(double bottomPad) {
    final content = Container(
      height: 72 + bottomPad,
      padding: EdgeInsets.only(bottom: bottomPad),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1628),
        border: Border(
          top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: List.generate(6, (i) => Expanded(child: _buildTab(i))),
      ),
    );

    if (kIsWeb) return content;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: content,
    );
  }

  Widget _buildTab(int index) {
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
                    child: _buildActivePill(index, unread),
                  )
                : _buildInactiveItem(index, unread),
          ),
        ),
      ),
    );
  }

  Widget _buildActivePill(int index, int unread) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x330EA5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x550EA5E9),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(index, true, unread),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              _labels[index],
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0EA5E9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveItem(int index, int unread) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIcon(index, false, unread),
        const SizedBox(height: 4),
        Text(
          _labels[index],
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: const Color(0x66FFFFFF),
          ),
        ),
      ],
    );
  }

  Widget _buildIcon(int index, bool isActive, int unread) {
    Widget icon;
    if (index == 5 && isActive && widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty) {
      icon = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF0EA5E9),
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
              color: const Color(0xFF0EA5E9),
              size: 18,
            ),
          ),
        ),
      );
    } else {
      icon = Icon(
        isActive ? _activeIcons[index] : _inactiveIcons[index],
        color: isActive
            ? const Color(0xFF0EA5E9)
            : const Color(0x66FFFFFF),
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
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
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