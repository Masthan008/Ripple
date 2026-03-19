import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

class LiquidNavbarItemWidget extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  final double selectedIconSize;
  final double unselectedIconSize;
  final double selectedFontSize;
  final double unselectedFontSize;
  final Color selectedColor;
  final Color unselectedColor;

  final EdgeInsetsGeometry padding;
  final int unreadCount;
  final String? userPhotoUrl;
  final bool isProfileTab;

  const LiquidNavbarItemWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.selectedIconSize = 24,
    this.unselectedIconSize = 22,
    this.selectedFontSize = 11,
    this.unselectedFontSize = 10,
    this.selectedColor = const Color(0xFF0EA5E9),
    this.unselectedColor = Colors.grey,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    this.unreadCount = 0,
    this.userPhotoUrl,
    this.isProfileTab = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (isProfileTab && userPhotoUrl != null && userPhotoUrl!.isNotEmpty) {
      iconWidget = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? selectedColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: userPhotoUrl!,
            width: 21,
            height: 21,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => IconTheme(
              data: IconThemeData(
                color: isSelected ? selectedColor : unselectedColor,
                size: (isSelected ? selectedIconSize : unselectedIconSize),
              ),
              child: icon,
            ),
          ),
        ),
      );
    } else {
      iconWidget = IconTheme(
        data: IconThemeData(
          color: isSelected ? selectedColor : unselectedColor,
          size: (isSelected ? selectedIconSize : unselectedIconSize),
        ),
        child: icon,
      );
    }

    if (unreadCount > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: unreadCount > 9 ? 4 : 0,
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
                  unreadCount > 99 ? '99+' : '$unreadCount',
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  color: isSelected ? selectedColor : unselectedColor,
                  fontSize: isSelected
                      ? selectedFontSize
                      : unselectedFontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
